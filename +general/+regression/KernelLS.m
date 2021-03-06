classdef KernelLS < KerMorObject & IKernelCoeffComp
    %KERNELLS Least-Squares kernel regression ("Rigde Regression")
    %   Since the systems can be considerably large, the pcg solver is used
    %   instead of plain inversion.
    %
    % @author Daniel Wirtz 21.03.2010
    %
    % @change{0,4,dw,2011-05-03} Removed `b` offset terms as no longer used in kernel expansions.
    %
    % @todo add unit test
    
    % @change{0,4,sa,2011-05-07} Implemented Setter for the properties G and Epsilon
    
    properties(SetObservable)
        % The kernel matrix to use for LS regression
        %
        % @propclass{data} Needed for LS to work in the first place.
        K;
        
        % The regularization term weight
        %
        % @propclass{important} If the data is badly conditioned increasing lambda can help.
        %
        % @type double @default 1
        lambda = 1;
        
        % Maximum iteration count for the conjugate gradient method
        %
        % @propclass{alglimit} Limits the iterations for the pcg method.
        %
        % See also: pcg, bicg
        CGMaxIt = [];
        
        % Tolerance for cg method
        %
        % @propclass{critical} The error tolerance for the pcg method.
        %
        % See also: pcg, bicg
        CGTol = 1e-6;
        
        % Maximum dimension of function for which direct inversion is
        % performed instead of pcg
        %
        % @propclass{optional} Direct inversion is more precise for small sizes. 
        %
        % @default 2000
        MaxStraightInvDim = 2000;
    end
    
    methods
        
        function this = KernelLS
            this = this@KerMorObject;
            this.registerProps('K','lambda','CGMaxIt','CGTol','MaxStraightInvDim');
        end
        
        function copy = clone(this)
            copy = general.regression.KernelLS;
            copy = clone@IKernelCoeffComp(this, copy);
            copy.MaxStraightInvDim = this.MaxStraightInvDim;
            copy.CGTol = this.CGTol;
            copy.CGMaxIt = this.CGMaxIt;
            copy.lambda = this.lambda;
            copy.K = this.K;
        end
        
        function [a, sf] = regress(this, fx, ainit)%#ok
            n = size(this.K,1);

            y = (fx*this.K)';
            M = this.K'*this.K + this.lambda*speye(n, n);
            
            if length(y) <= this.MaxStraightInvDim
                a = M\y;
                sf = StopFlag.SUCCESS;
            else
                %| @todo -why does pcgs pcg not work here? matrix is symmetric!
                [a, flag] = bicg(M,y,this.CGTol, this.CGMaxIt);%#ok
                %| @todo return correct stop flag
                sf = StopFlag.SUCCESS;
            end
        end
        
        %% IKernelCoeffComp interface members
        function init(this, kexp)
            % Sets the kernel matrix.
            %
            % Parameters:
            % kexp: The kernel expansion @type kernels.KernelExpansion
            this.K = kexp.getKernelMatrix;
        end
        
        function [ai, svidx, sf] = computeKernelCoefficients(this, yi, initialai)%#ok
            [ai, sf] = this.regress(yi);
            svidx = 1:size(yi,2);
        end
        
        %% Getter & setter
        function set.K(this, value)
            if (isa(value,'handle') && ~isa(value, 'data.FileMatrix')) || (~ismatrix(value) || ~isa(value,'double'))
                error('Value must be a data.FileMatrix or a double matrix.');
            end
            this.K = value;
        end
        
        function set.lambda(this, value)
            if ~isposrealscalar(value)
                error('value must be a positive scalar');
            end
            this.lambda = value;
        end
        
        function set.CGMaxIt(this, value)
            if ~isempty(value) && ~isposintscalar(value)
                error('value must be a positive integer scalar');                
            end
            this.CGMaxIt = value;
        end
        
        function set.CGTol(this, value)
            if ~isposrealscalar(value)
                error('value must be a positive real scalar.');                
            end
            this.CGTol = value;
        end
        
        function set.MaxStraightInvDim(this, value)
            if ~isposintscalar(value)
                error('value must be a positive integer scalar');                
            end
            this.MaxStraightInvDim = value;
        end
    end
 end
