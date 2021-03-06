classdef BaseGeometry < handle
%

    properties(SetAccess=protected)
        % n x 3 position vector of nodes
        Nodes;
        
        % m x p index vector for all p nodes of m elements
        Elements;
        
        % 2 x k index vector for edges between two points
        Edges;
        
        DofsPerElement;
        
        MasterFaces;
        
        % The indices of the nodes suitable for creating a patch surface
        % object
        PatchFacesIdx;
        PatchesPerFace;
        
        % A 2 x N_F vector containing the element number in the first row
        % and the face number on that element in the second row.
        Faces;
        
        OrientationCheckIndices;
        ReverseAxesIndices;
    end
    
    properties(Dependent)
        NumElements;
        NumNodes;
        NumFaces;
        NodesPerFace;
        
        % Returns the width of the geometry (x-range)
        Width;
        
        % Returns the Depth of the geometry (y-range)
        Depth;
        
        % Returns the Height of the geometry (z-range)
        Height;
    end
    
    properties(SetAccess=private)
        
        
        % Faces are:
        % Idx : 1     2      3      4    5      6
        % Face: X-    X+     Y-     Y+   Z-     Z+
        % Pos:  Left  Right  Front  Rear Bottom Top
        FaceNormals = [-1 1  0 0  0 0
                        0 0 -1 1  0 0
                        0 0  0 0 -1 1];
                    
                    
        FaceDims = logical([0 0 1 1 1 1
                            1 1 0 0 1 1
                            1 1 1 1 0 0]);
                        
        PatchFaces;
    end
    
    methods
        
        function this = BaseGeometry
            % 
        end
        
        function plot(this, withdofnr, elem, pm)
            
            if nargin < 4
                if nargin < 3
                    elem = 1:this.NumElements;
                    if nargin < 2
                        withdofnr = false;
                    end
                end
                pm = PlotManager;%(false,1,2);
                pm.LeaveOpen = true;
            end
            
            p = this.Nodes;
            h = pm.nextPlot('geometry',sprintf('Geometry (%s)',class(this)), 'x [mm]', 'y [mm]');
            plot3(h,p(1,:),p(2,:),p(3,:),'k.','MarkerSize',14);
            hold(h,'on');
            for k = 1:length(elem)
                el = this.Elements(elem(k),:);
                center = sum(p(:,el),2)/this.DofsPerElement;
                text(center(1),center(2),center(3),sprintf('E_{%d}',elem(k)),'Parent',h,'Color','m');
                % Plot local numbering for first element
                if k == 1
                    off = .04;
                    for i = 1:this.DofsPerElement
                        text(off+p(1,el(i)),off+p(2,el(i)),off+p(3,el(i)),sprintf('%d',i),'Parent',h,'Color','r');
                    end
                    for i = 1:6
                        facenodes = p(:,el(this.MasterFaces(i,:)));
                        mid = mean(facenodes,2);
                        text(mid(1),mid(2),mid(3),sprintf('F_%d',i),'Parent',h,'Color','k');
                    end
                end
            end
            eg = this.Edges;
            for i = 1:size(eg,1)
                plot3(h,[p(1,eg(i,1)) p(1,eg(i,2))],[p(2,eg(i,1)) p(2,eg(i,2))],[p(3,eg(i,1)) p(3,eg(i,2))],'r');
            end
            if withdofnr
                for k = 1:this.NumNodes
                    text(p(1,k),p(2,k),p(3,k),sprintf('%d',k),'Parent',h,'Color','k');
                end
            end
            zlabel('z [mm]');
            view(h,[52 30]);
            daspect([1 1 1]);
                        
            if nargin < 3
                pm.done;
            end
        end
        
%         function area = getFaceArea(this, elem, face)
%             nodes = this.Nodes(:,this.Elements(elem,this.MasterFaces(face,:)));
%         end
        
        function bounds = getBoundingBox(this, marginfac)
            if nargin < 2
                marginfac = 1;
            end
            m = min(this.Nodes,[],2)*marginfac;
            M = max(this.Nodes,[],2)*marginfac;
            bounds = [m(1) M(1) m(2) M(2) m(3) M(3)];
        end
        
        function commonidx = getCommonNodesWith(this, other)
            commonidx = Utils.findVecInMatrix(this.Nodes,other.Nodes);
        end
        
        function swapYZ(this)
            error('not implemented');
        end
        
        function copy = scale(this, factor)
            mc = metaclass(this);
            pts = this.Nodes * factor;
            cubes = this.Elements;
            eval(sprintf('copy = %s(pts,cubes);',mc.Name));
        end
        
        function reverseAxis(this, dim)
            this.reverseElementAxis(dim, 1:this.NumElements);
        end
        
        function [sub, nodeidx, faces] = getSubMesh(this, elems, faces)
            newelems = this.Elements(elems,:)';
            nodeidx = unique(newelems(:),'stable');
            newnodes = this.Nodes(:,nodeidx);%#ok
            % Fit element node reference indices
            invidx(nodeidx) = 1:length(nodeidx);
            newelems = invidx(newelems)';%#ok
            sub = eval([class(this) '(newnodes, newelems)']);
            
            % Auto-detect which faces are included for the submesh's
            % elements if none are specified
            if nargin < 3
                isface = false(1,size(this.NumFaces,2));
                for k = elems
                    isface = isface | this.Faces(1,:) == k;
                end
                faces = find(isface);
            end
            sub.Faces = this.Faces(:,faces);
            
            % Fit face reference indices
            invidx = [];
            invidx(elems) = 1:length(elems);
            sub.Faces(1,:) = invidx(sub.Faces(1,:));
            sub.faceComputations;
        end
        
        function toCMGUI(this, folder, name)
            if nargin < 3
                name = 'musclegeom';
                if nargin < 2
                    folder = pwd;
                end
            end
            %% exnode file
            exnode = fullfile(folder,[name '.exnode']);
            f = fopen(exnode,'w+');
            fprintf(f,'Group name : %s\n',name);
            fprintf(f,'#Fields=1\n');
            fprintf(f,'1) coordinates, coordinate, rectangular cartesian, #Components=3\n');
            fprintf(f,'x.  Value index= 1, #Derivatives= 0\n');
            fprintf(f,'y.  Value index= 2, #Derivatives= 0\n');
            fprintf(f,'z.  Value index= 3, #Derivatives= 0\n');
            for n = 1:this.NumNodes
                fprintf(f,'Node:\t%d\n',n);
                fprintf(f,'%E\n',this.Nodes(:,n));
            end
            fclose(f);
            
            %% exelem file
            exelem = fullfile(folder,[name '.exelem']);
            f = fopen(exelem,'w+');
            fprintf(f,'Group name : %s\n',name);
            %fprintf(f,'#Fields=0\n');
            
            % 1D elements - lines
            fprintf(f,'Shape.  Dimension=1\n');
            for e = 1:size(this.Edges,1)
                fprintf(f,'Element: 0 0 %d\n',e);
            end
            
            % 2D elements - faces
            fprintf(f,'Shape.  Dimension=2\n');
            for fa = 1:size(this.Faces,2)
                fprintf(f,'Element: 0 %d 0\n',fa);
                fprintf(f,'  Faces:\n');
                elem = this.Faces(1,fa);
                % PatchFacesIdx returns the node positions in an order you can
                % derive lines from it, MasterFaces doesn't
                facenodeidx = this.Elements(elem,this.PatchFacesIdx(this.Faces(2,fa),:));
                % Insert last edge closing the face
                facenodeidx = sort([facenodeidx; facenodeidx(2:end) facenodeidx(1)]);
                edgenumbers = Utils.findVecInMatrix(this.Edges',facenodeidx);
                fprintf(f,'    0 0 %d\n',edgenumbers);
            end
            
            % 3D elements
            fprintf(f,'Shape.  Dimension=3\n');
            fprintf(f,'#Scale factor sets=0\n');
            fprintf(f,'#Nodes=0\n');
%             fprintf(f,'#Nodes=%d\n',size(this.Elements,2));
            fprintf(f,'#Fields=0\n');
%             fprintf(f,'1) coordinates, coordinate, rectangular cartesian, #Components=3\n');
%             fprintf(f,'x.  l.Lagrange*l.Lagrange*l.Lagrange, no modify, standard node based.\n');
%             fprintf(f,'y.  l.Lagrange*l.Lagrange*l.Lagrange, no modify, standard node based.\n');
%             fprintf(f,'z.  l.Lagrange*l.Lagrange*l.Lagrange, no modify, standard node based.\n');
            for m = 1:this.NumElements
                fprintf(f,'Element: %d 0 0\n',m);
                % See if this element has any faces
                facesofelem = find(this.Faces(1,:) == m);
                if ~isempty(facesofelem)
                    fprintf(f,'  Faces:\n');
                    fprintf(f,'    0 %d 0\n',facesofelem);
                end
                fprintf(f,'  Nodes: %s\n',sprintf('%d\t',this.Elements(m,:)));
            end
            
            fclose(f);
        end
           
    end
    
    methods(Access=protected)
        function faces = computeFaces(this)
            % Computes the outward faces of this fem.geometry.
            %
            % Return values:
            % faces: A 2 x P index matrix of all P faces, containing the
            % element index in the first row and the face number of that
            % element that is outward in the second row. The face number is
            % assigned as in FaceNormals.
            % inner: A NumElements x 6 matrix with the indices of elements
            % whose faces are opposing each other. Each column corresponds
            % to the face number 1 to 6, sorted as given in FaceNormals.
            if this.NumElements > 1
                inner = zeros(this.NumElements,6);
                for Afaceidx = 1:6
                    for Bfaceidx = 1:6
                        if Afaceidx ~= Bfaceidx
                            % Also sort the element node indices in case of
                            % nonidentical numbering within each element
                            A = sort(this.Elements(:,this.MasterFaces(Afaceidx,:)),2);
                            B = sort(this.Elements(:,this.MasterFaces(Bfaceidx,:)),2);
                            for l = 1:this.NumElements
                                opposing = sum(abs(A - circshift(B,l-1)),2) == 0;
                                if any(opposing)
                                    opposedto = circshift(opposing,-(l-1));
                                    inner(opposing, Afaceidx) = find(opposedto);
                                    inner(opposedto, Bfaceidx) = find(opposing);
                                end
                            end
                        end
                    end
                end
                [elemnr, facenr] = find(inner == 0);
                faces = [elemnr facenr]';
            else
                mf = size(this.MasterFaces,1);
                faces = [ones(1,mf); 1:mf];
            end
            this.faceComputations(faces);
        end
        
        function faceComputations(this, faces)
            %% Also compute the PatchFaces index matrix
            if ~isempty(this.PatchFacesIdx)
                if nargin < 2
                    faces = this.Faces;
                end
                nf = size(faces,2);
                ppf = this.PatchesPerFace;
                %np = size(this.PatchFacesIdx,1);
                pf = zeros(nf*ppf,size(this.PatchFacesIdx,2));
                for k=1:nf
                    elem = faces(1,k);
                    face = faces(2,k);
                    pos = (face-1)*ppf + (1:ppf);
                    patchidx = this.PatchFacesIdx(pos,:);
                    pf((k-1)*ppf+(1:ppf),:) = reshape(this.Elements(elem,patchidx),ppf,[]);
                end
                this.PatchFaces = pf;
            end
        end
        
        function checkOrientation(this)
            return;
            oi = this.OrientationCheckIndices;
            pi = ProcessIndicator('%s: Checking orientation of %d elements in x,y,z directions',3*this.NumElements,false,class(this),this.NumElements);
            for dim = 1:3
                for e = 1:this.NumElements
                    chk = diff(reshape(this.Nodes(dim,this.Elements(e,oi(:,:,dim)')'),size(oi,2),[]),[],1);
                    if any(chk <= 0)
                        if all(chk < 0)
                            this.reverseElementAxis(dim, e);
                            %fprintf('Axis %d has negative orientation. Reversing element %d\n',dim,e);
                        else
                            [ip,jp] = find(chk > 0);
                            [in,jn] = find(chk < 0);
                            [is,js] = find(chk == 0);
                            if ~isempty(is)
                                errel = this.Elements(e,oi(js,[is is+1]',dim));
                                fprintf('\n%s: Degenerate element nr %3d in dimension %d: %3d equal! Nodes %s (%s)\n',...
                                    class(this),e,dim,length(is),int2str(errel),num2str(this.Nodes(dim,errel)));
                            else
                                if length(ip) > length(in)
                                    i = in; j = jn;
                                    str = 'positive';
                                    reverse = false;
                                else
                                    i = ip; j = jp;
                                    str = 'negative';
                                    reverse = true;
                                end
                                errel = this.Elements(e,oi(j,[i i+1],dim));
                                fprintf('\n%s: Opposite orientation in dimension %d in mainly %s oriented element nr %3d (%3d pos/%3d neg): Nodes %s (%s)\n',...
                                    class(this),dim,str,e,length(ip),length(in),int2str(errel),num2str(this.Nodes(dim,errel)));
                                if reverse
                                    this.reverseElementAxis(dim, e);
                                end
                            end
                        end
                    end
                    pi.step;
                end
            end
            pi.stop;
        end
    end
    
    methods(Access=private)
        function reverseElementAxis(this, dim, e)
            this.Elements(e,:) = this.Elements(e,this.ReverseAxesIndices(dim,:));
        end
    end
    
    methods
        function nc = get.NumElements(this)
            nc = size(this.Elements,1);
        end
        
        function nc = get.NumNodes(this)
            nc = size(this.Nodes,2);
        end
        
        function nf = get.NumFaces(this)
            nf = size(this.Faces,2);
        end       
        
        function npf = get.NodesPerFace(this)
            npf = size(this.MasterFaces,2);
        end
        
        function w = get.Width(this)
            w = max(this.Nodes(1,:))-min(this.Nodes(1,:));
        end
        
        function w = get.Depth(this)
            w = max(this.Nodes(2,:))-min(this.Nodes(2,:));
        end
        
        function w = get.Height(this)
            w = max(this.Nodes(3,:))-min(this.Nodes(3,:));
        end
    end
    
    methods(Static)
        function res = test_DemoGrids
            fem.geometry.RegularHex8Grid(1:3);
            fem.geometry.RegularHex8Grid(1:3,1:4);
            fem.geometry.RegularHex8Grid(1:3,1:4,-1:3);
            fem.geometry.RegularHex8Grid(1:3,1:4,-1:3,.2);
            fem.geometry.RegularHex20Grid(1:2);
            fem.geometry.RegularHex20Grid(1:2,0:2);
            fem.geometry.RegularHex20Grid(-1:1,1:3,-1:1);
            fem.geometry.RegularHex20Grid(-1:1,1:2,-1:1,.2);
            res = true;
        end
        
        function test_subMesh
            g = fem.geometry.RegularHex27Grid(-1:1,1:2,-1:1,.2);
            [sg, node] = g.getSubMesh(1:3:g.NumElements);
            sg.plot;
            g = fem.geometry.RegularHex8Grid(-20:1,1:4,-1:1,.2);
            [sg, node] = g.getSubMesh([1 5 9 10 15 56 79 99]);
            sg.plot;
        end
        
        function res = test_BellyGeometryGeneration
            g = fem.geometry.Belly(1,'InnerRadius',.2,'Gamma',7);
            g = fem.geometry.Belly(35,'InnerRadius',[.2 .6],'Gamma',5);
            g = fem.geometry.Belly(linspace(0,35,5),'InnerRadius',.2,'Gamma',[10 20]);
            g = fem.geometry.Belly(linspace(0,35,3),'InnerRadius',[.2 .6],'Gamma',[10 20]);
            g = fem.geometry.Belly([0 1 3.125 3.25 3.26 4 4.5 4.75 5 6 10 35],...
                'InnerRadius',[.2 .6],'Gamma',[10 20]);
            g = fem.geometry.Belly(20,'Radius',[4 2],'InnerRadius',.5,'Gamma',[10 20]);
            g = fem.geometry.Belly(sort(rand(1,10)*3),'Radius',@(x)[sqrt(abs(x)); 1./(x-34).^2],'InnerRadius',.2);
            g.plot;
            g = fem.geometry.Belly(35,'Radius',@(x)sqrt(abs(x)));
            g.plot;
            g = fem.geometry.Belly(0:4:20,'Radius',[4 2],'InnerRadius',.5,...
                'Gamma',[10 20],'MinZ',-1.5);
            g.plot;
            g = fem.geometry.Belly(10:3:35,'Radius',@(x)sqrt(abs(x)),'Layers',[.4 .7 1]);
            g.plot;
            res = 1;
        end
    end
    
    
end