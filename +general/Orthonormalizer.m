classdef Orthonormalizer < KerMorObject
    % Class that supports orthonormalization of vectors.
    %
    % At the orthonormalization process a matrix G can be defined that
    % defines the scalar product with respect to which the vectors are
    % orthonormalized.
    %
    % Original algorithm code from Bernard Haasdonk, rbmatlab.
    % See rbmatlabroot/general/vecmat/orthonormalize*.m
    %
    % @author Daniel Wirtz @date 24.08.2010
    %
    % @change{0,3,sa,2011-05-07} Implemented Setter for the properties G
    % and Epsilon
    %
    % This class is part of the framework
    % KerMor - Model Order Reduction using Kernels:
    % - \c Homepage http://www.morepas.org/software/index.html
    % - \c Documentation http://www.morepas.org/software/kermor/index.html
    % - \c License @ref licensing     
    
    properties
        % The scalar product matrix `<x,x> := x^tGx`
        %
        % Defaults to `I_d`
        G = 1;
        
        % Tolerance for zero columns at orthogonalization.
        Epsilon = 1e-7;
        
        % The orthogonalization algorithm used.
        %
        % Possible choices are:
        % "gs": Gram-Schmidt
        % "ch": Cholesky-Decomposition
        % "qr": QR-Decomposition
        %
        % @note Currently only "gs" is working properly.
        %
        % Default: "gs"
        Algorithm = 'gs';
    end
    
    methods
        function onvec = orthonormalize(this, vec)
            % Performs orthogonalization using the given column vectors vec
            % and the scalar product induced by the matrix G.
            %
            % Parameters:
            % vec: A matrix containing the column vectors to orthogonalize.
            
            % Check for nonempty vec
            if isempty(vec)
                onvec = zeros(size(vec));
                return;
            end
            
            % Check on identity of vectors
            for i=1:(size(vec,2)-1)
                for j=(i+1):size(vec,2)
                    if isequal(vec(:,i),vec(:,j))
                        vec(:,j) = 0;
                    end;
                end;
            end
            
            if strcmp(this.Algorithm,'gs')
                onvec = this.ortho_gs(vec);
            elseif strcmp(this.Algorithm,'qr')
                onvec = this.ortho_qr(vec);
            elseif strcmp(this.Algorithm,'ch')
                onvec = this.ortho_ch(vec);
            end
        end
        
        function set.G(this, value)
            if ~isa(value, 'double')
                error('G should be a double matirx');
            end
            this.G = value;
        end
        
        function set.Epsilon(this, value)
            if ~isposrealscalar(value)
                error('value must be a positive real scalar.');
            end
            this.Epsilon = value;
        end
        
        function set.Algorithm(this, value)
            if ~any(strcmp(value,{'gs' 'qr' 'ch'}))
                error('Invalid method: %s',value);
            end
            this.Algorithm = value;
        end
    end
    
    methods(Access=private)
        function onvec = ortho_gs(this, vec)
            % Performs gram-schmidt orthogonalization.
            %
            % Parameters:
            % vec: The column vectors to orthogonalize.
            
            onvec = vec;
            for i = 1:size(vec,2)
                % orthogonalize next vector i and assume, that it is already
                % orthogonal to previous ones
                n = sqrt(onvec(:,i)' * this.G * onvec(:,i));
                if (n < this.Epsilon)
                    onvec(:,i) = 0;
                else
                    onvec(:,i) = onvec(:,i)/n;
                end
                
                % orthogonalize remaining vectors wrt this one:
                A_mult_onvec_i = this.G*onvec(:,i);
                
                % create row-vector with projections on the created on-vector
                coeffs= A_mult_onvec_i' * onvec(:,i+1:end);
                
                % create matrix of scaled versions of actual orthonormalized vector
                coeffmat = onvec(:,i) * coeffs;
                
                % perform orthogonalization
                onvec(:,i+1:end) = onvec(:,i+1:end) - coeffmat;
            end
            
            % eliminate zero-columns
            nsqr = Norm.L2(onvec);
            onvec = onvec(:,nsqr > 0.1);
        end
        
        function onvec = ortho_qr(this, vec)
            if 1==1 
                error('Algorithm "qr" not working. Need to check.'); 
            end
            onvec = vec;
            
            % incomplete cholesky of inner-product matrix:
            R_M = ichol(sparse(this.G),'inf');
            
            % qr decomposition of R_M * X with permutation indices E
            [Q, R, E]= qr(R_M * onvec, 0);
            
            % sort such that linear independent first and Q * R = R_M * Xon
            onvec = onvec(:,E);
            
            % search nonvanishing diagonal entries of R
            ind = find(abs(diag(R)) > this.Epsilon);
            onvec = onvec(:,ind);
            Rind = R(ind,ind);
            onvec = onvec(:,ind) / Rind;
        end
        
        function onvec = ortho_ch(this, vec)
            if 1==1 
                error('Algorithm "ch" not working. Need to check.'); 
            end
            onvec = vec;
            
            % get gram matrix
            Gr = onvec' * this.G * onvec;
            Gr = 0.5* (Gr + Gr');
            
            options.droptol = this.Epsilon;
            
            %R = full(cholinc(sparse(G),'inf')); % fill small diagonal entries with inf
            %R = full(cholinc(sparse(G),options)); % fill small diagonal entries with inf
            
            % cholesky with dropvalue epsilon
            % If an error gets thrown here, you might have an older matlab
            % version only knowing "cholinc" as command, which has been
            % replaced by "ichol" as of R2013A.
%             R = full(cholinc(sparse(Gr),this.Epsilon)); 
            R = full(ichol(sparse(Gr),options));
            
            ind = find(diag(R) > this.Epsilon);
            onvec = onvec(:,ind);
            Ri = R(ind,ind);
            onvec = onvec / Ri;
            
            % eliminate too small or too large vectors:
            norms = onvec' * this.G * onvec;
            onvec = onvec(:,abs(diag(norms)-1)<0.5);
        end
    end
    
    methods(Static)
        function res = test_Orthogonalization
            res = true;
            for k = 1:5
                d2 = randi(200);
                d1 = d2 + k*randi(10);
                
                A = rand(d1,d2);

                o = general.Orthonormalizer;
                o.Algorithm = 'gs';
                ov1 = o.orthonormalize(A);
    %             o.Algorithm = 'ch';
    %             ov2 = o.orthonormalize(A);
    %             o.Algorithm = 'qr';
    %             ov3 = o.orthonormalize(A)

    %             res = norm(ov1-ov2) < sqrt(eps);
                res = res & isequal(round(ov1'*ov1),eye(d2));
                res = res & abs(norm(ov1'*ov1)-1) < 1000*eps;
            end
        end
    end
    
end

