classdef Constant < error.alpha.Base
% Constant: 
%
%
%
% @author Daniel Wirtz @date 2011-07-04
%
% @new{0,5,dw,2011-07-04} Added this class.
%
% This class is part of the framework
% KerMor - Model Order Reduction using Kernels:
% - \c Homepage http://www.agh.ians.uni-stuttgart.de/research/software/kermor.html
% - \c Documentation http://www.agh.ians.uni-stuttgart.de/documentation/kermor/
% - \c License @ref licensing
    
    properties(Access=private)
        M2 = [];
        M3 = [];
    end
    
    methods
        
        function this = Constant(rmodel)
            this = this@error.alpha.Base(rmodel);
        end
        
        function inputOfflineComputations(this, rmodel, M)
            fm = rmodel.FullModel;
            
            if ~isempty(fm.System.B)
                try
                    B = fm.System.B.evaluate([],[]);
                catch ME%#ok
                    B = fm.System.B.evaluate(0,rmodel.System.getRandomParam);
                    warning('Some:Id','Error estimator for current system will not work correctly! (B is not linear and mu-independent!');
                end
            
                if ~isempty(rmodel.V) && ~isempty(rmodel.W)
                    % Only linear input conversion (B = const. matrix) allowed so
                    % far! mu,0 is only to let
                    
                    B2 = B-rmodel.V*(rmodel.W'*B);
                    this.M2 = M'*(rmodel.GScaled*B2);
                    this.M3 = B2'*(rmodel.GScaled*B2);
                    clear B2;
                else
                    % No projection means no projection error!
                    n = size(this.M1,2);
                    b = size(B,2);
                    this.M2 = zeros(n,b);
                    this.M3 = zeros(b,b);
                end
            end
        end
        
        function a = getAlpha(this, phi, ut, t, mu)%#ok
            a = phi*this.M1*phi';
            if ~isempty(ut) % An input function u is set
                a = a + phi*this.M2*ut + ut'*this.M3*ut;
            end
            a = sqrt(abs(a));
            %a = sqrt(max(a,0));
        end
    end
    
end