classdef ModelAnalyzer < handle;
%ModelAnalyzer: Analysis tools for reduced models and approximations
%
% @author Daniel Wirtz @date 2011-11-17
%
% @change{0,6,dw,2011-11-17} Moved this class to the +tools package from visual.
%    
% This class is part of the framework
% KerMor - Model Order Reduction using Kernels:
% - \c Homepage http://www.agh.ians.uni-stuttgart.de/research/software/kermor.html
% - \c Documentation http://www.agh.ians.uni-stuttgart.de/documentation/kermor/
% - \c License @ref licensing 
%
% @todo think of expressive names for methods
    
    properties
        SingleFigures = false;
        
        UseOutput = true;
    end
    
    properties(Access=private)
        rm;
    end
    
    methods
        
        function this = ModelAnalyzer(rmodel)
           if ~isa(rmodel,'models.ReducedModel')
               error('rmodel must be a models.ReducedModel subclass.');
           end
           this.rm = rmodel; 
        end
        
        function errs = getRedErrForParamSamples(this)
            fm = this.rm.FullModel;
            errs = zeros(2,fm.Data.SampleCount);
            for pidx = 1:fm.Data.SampleCount
                mu = fm.Data.ParamSamples(:,pidx);
                y = fm.Data.getTrajectory(mu,[]);
                [~, yr] = this.rm.simulate(mu,[]);
                errs(1,pidx) = max(sqrt(sum((yr-y).^2))); %linf l2 err
                errs(2,pidx) = max(max(abs(yr-y),[],1)); %linf linf err
            end
        end
        
        function compareRedFull(this, mu, inputidx)
            % Compares the solutions of the reduced model and the associated full model by
            % calling the BaseModel.plot method for both solutions and again for the
            % difference. Also some information of `l^2` and `l^\infty` errors are printed.
            %
            % Parameters:
            % mu: The concrete mu parameter sample to simulate for.
            % inputidx: The index of the input function to use.
            if nargin < 3
                inputidx = [];
                if nargin < 2
                    mu = [];
                end
            end
            fm = this.rm.FullModel;
            tic;
            [~,y] = fm.simulate(mu,inputidx);
            ftime = toc;
            tic;
            [ti,yr] = this.rm.simulate(mu,inputidx);
            rtime = toc;
            %% Text output
            str = sprintf('%s, mu=[%s], u_%d',fm.Name,...
                general.Utils.implode(mu,', ','%2.3f'),inputidx);
            fprintf('Computation times %s:\n',str);
            t = PrintTable;
            t.addRow('Full model',sprintf('%2.4fs',ftime));
            t.addRow('Reduced model',sprintf('%2.4fs',rtime));
            t.addRow('Speedup',sprintf('%2.4fs',ftime/rtime));
            t.display;
            fprintf('Error comparison for %s:\n',str);
            % L^2 errors
            l2 = sqrt(sum((yr-y).^2));
            lil2 = max(l2);
            l2l2 = sqrt(sum(l2.^2));
            meanl2 = mean(l2);
            l2relyl2 = l2 ./ sqrt(sum(y.^2));
            l2l2relyl2 = sqrt(sum(l2relyl2.^2));
            lil2relyl2 = max(l2relyl2);
            meanrell2 = mean(l2relyl2);
            %fprintf('||y(t_i)||_2: %s',general.Utils.implode(l2,', ','%2.3f'));
            t = PrintTable;
            t.addRow('L2 time and space error','L^2(||y(t) - yr(t)||_2,[0,T])',l2l2);
            t.addRow('Linf time and L2 space error','L^inf(||y(t) - yr(t)||_2,[0,T])',lil2);
            t.addRow('Relative L2 time and space error','L^2(||(y(t) - yr(t)) / y(t)||_2,[0,T])',l2l2relyl2);
            t.addRow('Relative Linf time and L2 space error', 'L^inf(||(y(t) - yr(t)) / y(t)||_2,[0,T])',lil2relyl2);
            t.addRow('Mean L2 error','Mean(||y(t) - yr(t)||_2,[0,T])',meanl2);
            t.addRow('Mean relative L2 error','Mean(||(y(t) - yr(t)) / y(t)||_2,[0,T])',meanrell2);
            
            % L^inf errors
            li = max(abs(yr-y),[],1);
            lili = max(li);
            l2li = sqrt(sum(li.^2));
            meanli = mean(li);
            lirelyli = li ./ max(abs(y),[],1);
            l2lirelyli = sqrt(sum(lirelyli.^2));
            lilirelyli = max(lirelyli);
            meanrelli = mean(lirelyli);
            %fprintf('||y(t_i)||_2: %s',general.Utils.implode(li,', ','%2.3f'));
            t.addRow('Linf time and space error','L^inf(||y(t) - yr(t)||_inf,[0,T])',lili);
            t.addRow('L2 time and Linf space error','L^2(||y(t) - yr(t)||_inf,[0,T])',l2li);
            t.addRow('Relative Linf time and space error','L^inf(||(y(t) - yr(t)) / y(t)||_inf,[0,T])',lilirelyli);
            t.addRow('Relative L2 time and Linf space error','L^2(||(y(t) - yr(t)) / y(t)||_inf,[0,T])',l2lirelyli);
            t.addRow('Mean Linf error','Mean(||y(t) - yr(t)||_inf,[0,T])',meanli);
            t.addRow('Mean relative Linf error','Mean(||(y(t) - yr(t)) / y(t)||_inf,[0,T])',meanrelli);
            t.display;
            
            %% Plotting
            fm.plot(ti,y);
            set(gcf,'Name',['Full simulation - ' str]);
            fm.plot(ti,yr);
            set(gcf,'Name',['Reduced simulation - ' str]);
            fm.plot(ti,abs(y-yr));
            set(gcf,'Name',['Absolute error - ' str]);
            hlp = abs(y);
            if any(hlp(:) == 0)
                hlp2 = hlp;
                hlp2(hlp==0) = [];
                ep = min(hlp2(:))^2;
                hlp(hlp==0) = ep;
            end
            fm.plot(ti,abs(y-yr)./hlp);
            set(gcf,'Name',['Relative error - ' str]);
        end
        
        function e = getTrajApproxError(this, mu, inputidx)
            % Computes the approximation training error on the trajectory
            % for given mu and inputidx.
            %
            % @todo include check for FullModel.Data if full traj is
            % already there
            fm = this.rm.FullModel;
            if ~isempty(fm.Approx)
                if nargin == 2
                    inputidx = [];
                end
                x = fm.Data.getTrajectory(mu, inputidx);
                if ~isempty(x)
                    fm.System.setConfig(mu, inputidx);
                    t = fm.scaledTimes;
                else
                    [t,x] = fm.computeTrajectory(mu, inputidx);
                end
                if ~isempty(fm.Data.V)
                    x = fm.Data.V*(fm.Data.W'*x);
                end
                mu = repmat(mu,1,numel(t));
                fx = fm.Approx.evaluate(x,t,mu);
                afx = fm.System.f.evaluate(x,t,mu);
                %e = sqrt(sum((fx-afx).^2,1));
                e = max(abs(fx-afx),[],1);
            else
                error('The approximation error can only be computed for models with an approx.BaseApprox instance present.');
            end
        end
        
        function h = analyzeError(this, mu, inputidx)
            if nargin < 3
                inputidx = [];
                if nargin < 2
                    mu = [];
                end
            end
            rmodel = this.rm;
            
            %% Initial computations
            [~, y, time, x] = rmodel.FullModel.simulate(mu, inputidx);
            rmodel.ErrorEstimator.Enabled = false;
            tic; rmodel.simulate(mu, inputidx); timer_noerr = toc;
            rmodel.ErrorEstimator.Enabled = true;
            [t, yr, timer, xr] = rmodel.simulate(mu, inputidx);
            
            if this.UseOutput
                x = y;
                xr = yr;
                est = rmodel.ErrorEstimator.OutputError;
            else
                if ~isempty(rmodel.V)
                    xr = rmodel.V*xr;
                end
                est = rmodel.ErrorEstimator.StateError;
            end
            e = sqrt(sum((x - xr).^2,1));
            xnorm = sqrt(sum(x.^2,1));
            erel = e./xnorm;
            estrel = est./xnorm;
            xrnorm = sqrt(sum(xr.^2,1));
            erelr = e./xrnorm;
            estrelr = est./xrnorm;
            
            %% System plot
            xrmin = xr-repmat(est,size(xr,1),1); xrplus = xr+repmat(est,size(xr,1),1);
            ymax = max([max(x(:)) max(xr(:)) max(xrmin(:)) max(xrplus(:))]);
            ymin = min([min(x(:)) min(xr(:)) min(xrmin(:)) min(xrplus(:))]);
            h = [];
            if this.SingleFigures
                %subplot(1,2,1);
                h(end+1)=figure;
            else
                h(1) = figure;
                pos = get(0,'MonitorPosition');
                set(h,'OuterPosition',pos(1,:));
                subplot(2,3,1);
            end
            plot(t,general.Utils.preparePlainPlot(x));
            xlabel('t');
            if this.UseOutput
                title(sprintf('The full system''s output (m=%d,time=%.3f)',size(x,1),time));
            else
                title(sprintf('The full system (d=%d,time=%.3f)',size(x,1),time));
            end
            axis([t(1) t(end) ymin ymax]);
            if this.SingleFigures
                h(end+1)=figure;
                %subplot(1,2,2);
            else
                subplot(2,3,2);
            end
            if this.UseOutput
                plot(t,general.Utils.preparePlainPlot(x),'b',...
                    t,general.Utils.preparePlainPlot(xr),'r',...
                    t,general.Utils.preparePlainPlot(xrmin),...
                    'r--',t,general.Utils.preparePlainPlot(xrplus),'r--');
                title(sprintf('Full+reduced system outputs with error bounds (r=%d,self time:%.3f, time with err est:%.3f)',size(rmodel.V,2),timer_noerr,timer));
                ylabel('y(t) / y^r(t)');
                legend('Full system','Reduced system','Lower bound','Upper bound');
            else
                plot(t,general.Utils.preparePlainPlot(xr),'r');
                title(sprintf('Reduced system (r=%d,self time:%.3f, time with err est:%.3f)',size(rmodel.V,2),timer_noerr,timer));
                ylabel('x^r(t)');
            end
            xlabel('t'); 
            axis([t(1) t(end) ymin ymax]);
            
            
            %% Absolute value plot
            if this.SingleFigures
                h(end+1)=figure;
                %subplot(1,2,1);
            else
                subplot(2,3,3);
            end
            plot(t,xnorm,'b',t,xrnorm,'r',t,xrnorm-est,'r--',t,xrnorm+est,'r--');
            xlabel('t');
            title('The state variable norms');
            legend('Full system','Reduced system','Lower bound','Upper bound');
            
            % Error plots
            if this.SingleFigures
                %subplot(1,2,2);
                h(end+1)=figure;
            else
                subplot(2,3,4);
            end
            semilogy(t,est,'b',t,e,'r');%,t,abs(e-est),'g');
            xlabel('t');
            title(sprintf('The state variable absolute errors.\nmean(e)=%g, mean(est)=%g',mean(e),mean(est)));
            legend('Estimated error','True error');%,'Location','Best');
            
            % Relative Error plots
            if this.SingleFigures
                h(end+1)=figure;
                %subplot(1,2,1);
            else
                subplot(2,3,5);
            end
            semilogy(t,estrel,'b',t,erel,'r');
            xlabel('t');
            title(sprintf(['The state variable relative errors (comp. to '...
                'full solution)\nmean(e_{rel})=%g, mean(est_{rel})=%g'],...
                mean(erel),mean(estrel)));
            legend('Estimated error','True error');%,'Location','Best');
            
            if this.SingleFigures
                %subplot(1,2,2);
                h(end+1)=figure;
            else
                subplot(2,3,6);
            end            
            semilogy(t,erelr,'r',t,estrelr,'b');
            xlabel('t');
            title(sprintf(['The state variable relative errors (comp. to '...
                'reduced solution)\nmean(ered_{rel})=%g, mean(estred_{rel})=%g'],...
                mean(erelr),mean(estrelr)));
            legend('True error','Estimated error');%,'Location','Best');
        end
    end
end
