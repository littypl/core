classdef GaussConfig < kernels.config.RBFConfig
% RBFConfig: 
%
% @docupdate
%
% @author Daniel Wirtz @date 2012-11-22
%
% @new{0,7,dw,2012-11-22} Added this class.
%
% This class is part of the framework
% KerMor - Model Order Reduction using Kernels:
% - \c Homepage http://www.agh.ians.uni-stuttgart.de/research/software/kermor.html
% - \c Documentation http://www.agh.ians.uni-stuttgart.de/documentation/kermor/
% - \c License @ref licensing
    
    properties(SetAccess=private)
        Distances;
        DistEps;
    end
    
    methods
        function this = GaussConfig(varargin)
            this = this@kernels.config.RBFConfig(varargin{:});
            i = inputParser;
            i.KeepUnmatched = true;
            i.addParamValue('D',[]);
            i.addParamValue('Eps',eps);
            i.parse(varargin{:});
            r = i.Results;
            if ~isempty(r.D)
                ke = kernels.GaussKernel;
                g = zeros(size(r.D));
                for k = 1:length(r.D)
                    g(k) = ke.setGammaForDistance(r.D(k),r.Eps);
                end
                this.Gammas = g;
                this.Distances = r.D;
                this.DistEps = r.Eps;
            else
                if isempty(this.Gammas)
                    error('You must pass either Gamma values (G) or distances (D)');
                end
            end
        end
        
        function str = getConfigurationString(this, nr)
            str = getConfigurationString@kernels.config.RBFConfig(this, nr);
            if ~isempty(this.Distances)
                str = sprintf('%s (by dist %g)',str,this.Distances(nr));
            end
        end
        
        function applyConfiguration(this, nr, kernel)
            if ~isempty(this.Distances)
                this.Gammas(nr) = kernel.setGammaForDistance(this.Distances(nr),this.DistEps);
            else
                applyConfiguration@kernels.config.RBFConfig(this, nr, kernel);
            end
        end
    end
end