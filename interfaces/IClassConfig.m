classdef IClassConfig < KerMorObject & ICloneable
% IClassConfig: Abstract interface for a set of configurations that can be applied to a given
% algorithm
%
% See also: kernels.RBFConfig general.regression.EpsSVRConfig
%
% @author Daniel Wirtz @date 2012-11-22
%
% @new{0,7,dw,2012-11-22} Added this class.
%
% This class is part of the framework
% KerMor - Model Order Reduction using Kernels:
% - \c Homepage http://www.morepas.org/software/index.html
% - \c Documentation http://www.morepas.org/software/kermor/index.html
% - \c License @ref licensing

    properties
        % The prototype class that is to be used as base class before
        % configuring a new instance.
        %
        % @type ICloneable
        Prototype;
    end
    
    properties(Access=protected)
        % Determines the class that is allowed to be configured.
        %
        % @type char @default []
        RequiredPrototypeClass = [];
    end
    
    methods(Sealed)
        function lbl = getAxisLabels(this, nrs)
            if nargin < 2
                nrs = 1:this.getNumConfigurations;
            end
            lbl = arrayfun(@convert,nrs,'Unif',false);
            
            function o = convert(e)
                tmp = this.getConfigurationString(e, true);
                o = Utils.implode(tmp,sprintf('/'));
            end
        end
        
        function t = getValueRanges(this)
            t = PrintTable;
            t.HasHeader = true;
            t.HasRowHeader = true;
            t.addRow('Location','Min','Max');
            this.collectRanges(t,{this.getClassName});
        end
    end
    
    methods
        function set.Prototype(this, value)
            if ~isa(value, 'ICloneable')
                error('The prototype must be a ICloneable descendant.');
            elseif ~isempty(this.RequiredPrototypeClass) && ...
                    ~isa(value,this.RequiredPrototypeClass)%#ok
                error('The prototype must be a %s descendant.',...
                    this.RequiredPrototypeClass);%#ok
            end
            this.Prototype = value;
        end
        
        function copy = clone(this, copy)
            if nargin < 2
                error('You must call this clone method passing a cloned subclass instance.');
            end
            % Dont clone the prototype here; it's cloned anyways every time
            % a new instance is configured.
            copy.Prototype = this.Prototype;
            copy.RequiredPrototypeClass = this.RequiredPrototypeClass;
        end
    end
    
    methods(Access=protected)
        function ptype = getProtoClass(this)
            if isempty(this.Prototype)
                error('No prototype set');
            end
            ptype = this.Prototype.clone();
        end
        
        function idx = getPartIndices(this, partNr, totalParts)
            rs = RangeSplitter(this.getNumConfigurations, 'Num', totalParts);
            idx = rs.getPart(partNr);
        end
        
        function addRange(~, ptable, proppath, minval, maxval)
            head = Utils.implode(proppath,'.');
            ptable.addRow(head,minval,maxval);
        end
    end
    
    methods(Abstract)
        % Returns the number of configurations that can be applied
        %
        % Return values:
        % n: The number of configurations @type integer
        n = getNumConfigurations(this);
        
        % Creates a new instance with given configuration
        %
        % Parameters:
        % nr: The configuration number @type integer
        %
        % Return values:
        % object: The configured object @type ICloneable
        object = configureInstance(this, nr);
        
        % Returns the number of configurations that can be applied
        %
        % Parameters:
        % nr: The configuration number @type integer
        % asCell: Flag to indicate that each setting that can be done should be placed in a
        % cell of a cell array. @type logical
        %
        % Return values:
        % str:  @type integer
        str = getConfigurationString(this, nr, asCell);
        
        % Returns a string of the changed properties by this IClassConfig instance
        %
        % Return values:
        % str: The string @type char
        str = getConfiguredPropertiesString(this);
        
        % Returns a sub-part of this configuration as a new instance.
        %
        % Use the helper method getPartIndices to obtain the correct indices of the
        % configurations that belong to a specific part.
        %
        % Parameters:
        % partNr: The part number @type integer
        % totalParts: The total number of parts @type integer
        %
        % Return values:
        % conf: A copy containing the configurations of the specified part @type IClassConfig
        conf = getSubPart(this, partNr, totalParts);
    end
    
    methods(Abstract, Access=protected)
        collectRanges(this, ptable, proppath);
    end
    
    methods(Access=protected)
        function obj = loadobj(obj, from)
            if nargin < 2 || ~isa(from,'IClassConfig')
                error('Must call this loadobj method from subclass with subclass instance');
            end
            obj = loadobj@KerMorObject(obj, from);
            obj.Prototype = from.Prototype;
            obj.RequiredPrototypeClass = from.RequiredPrototypeClass;
        end
    end
    
    methods(Static)
        function test_ClassConfigPlots
            
            pm = PlotManager(false,2,2);
            pm.LeaveOpen = true;
            runTest(kernels.config.RBFConfig('G',.4:.01:.6));
            runTest(kernels.config.GaussConfig('G',1:10));
            runTest(kernels.config.WendlandConfig('G',1:5,'S',(1:5)/2,'D',2));
            
            pm.done;
            
            function runTest(c)
                fprintf('%s: %s',c.getClassName,c.getConfiguredPropertiesString);
                nc = c.getNumConfigurations;
                x = 1:nc;
                fx = ones(size(x));
                h = pm.nextPlot(c.getClassName,c.getClassName);
                plot(h,x,fx);
                set(h,'XTick',1:nc,'XTickLabel',c.getAxisLabels);
                disp(c.getAxisLabels);
            end            
        end
    end
    
end