classdef AffineInitialValue < dscomponents.AInitialValue & general.AffParamMatrix
% AffineInitialValue: Parameter-affine initial value for dynamical systems.
%
% Extends the standard AffParamMatrix from the general package.
%
% @author Daniel Wirtz @date 2011-07-04
%
% @new{0,5,dw,2011-07-04} Added this class.
%
% This class is part of the framework
% KerMor - Model Order Reduction using Kernels:
% - \c Homepage http://www.morepas.org/software/index.html
% - \c Documentation http://www.morepas.org/software/kermor/index.html
% - \c License @ref licensing
    
    methods
        function x0 = evaluate(this, mu)
            x0 = this.compose(mu);
        end
        
        function x0 = compose(this, mu)
            % Call affine function evaluate
            x0 = full(compose@general.AffParamMatrix(this, 0, mu));
        end
        
        function projected = project(this, V, W)%#ok
            % Projects the affine parametric initial value into the subspace spanned by
            % `V,W`.
            
            % Uses the overridden operators in AffParamMatrix to create a copy.
            projected = W'*this;
            % Dont store V,W due to hard drive space saving (not really needed here)
            %projected = project@general.AProjectable(this, V, W, projected);
        end
        
        function copy = clone(this)
            copy = clone@general.AffParamMatrix(this,...
                dscomponents.AffineInitialValue);
        end
    end
    
end