classdef ConstInitialValue < dscomponents.AInitialValue
% ConstInitialValue: A constant initial value.
%
%
%
% @author Daniel Wirtz @date 2011-07-04
%
% @new{0,5,dw,2011-07-04} Added this class. Provides constant initial values for dynamical systems.
%
% This class is part of the framework
% KerMor - Model Order Reduction using Kernels:
% - \c Homepage http://www.morepas.org/software/index.html
% - \c Documentation http://www.morepas.org/software/kermor/index.html
% - \c License @ref licensing

    properties(SetAccess=private)
        x0;
    end
        
    methods
        
        function this = ConstInitialValue(x0)
            this.x0 = x0;
        end
        
        function x0 = evaluate(this, mu)
            if ~isempty(mu)
                x0 = repmat(this.x0,1,size(mu,2));
            else
                x0 = this.x0;
            end
        end
        
        function projected = project(this, V, W)%#ok
            % Dont store V,W due to hard drive space saving (not really needed here)
            %projected = project@general.AProjectable(this, V, W, this.clone);
            projected = this.clone;
            projected.x0 = W'*this.x0;
        end
        
        function copy = clone(this)
            copy = dscomponents.ConstInitialValue(this.x0);
            copy = clone@general.AProjectable(this, copy);
        end
    end
    
end