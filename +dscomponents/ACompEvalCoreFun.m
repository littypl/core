classdef ACompEvalCoreFun < dscomponents.ACoreFun
% ACompEvalCoreFun: A normal CoreFun which supports single-component
% evaluation.
%
% This extra abilities are used within the approx.DEIM approximation.
%
% @author Daniel Wirtz @date 2012-03-26
%
% @new{0,6,dw,2012-06-06} Added new methods
% ACompEvalCoreFun.evaluateJacobianSet and
% ACompEvalCoreFun.evaluateComponentPartialDerivatives to support jacobian
% entry evaluation for this class of functions (they inherit the same
% sparsity access to components). Also updated the test_CompEvalMatch to
% use random point sets and not only the full set (but that also)
%
% @new{0,6,dw,2012-05-30} Added the
% ACompEvalCoreFun.evaluateComponentSetGradients and
% ACompEvalCoreFun.evaluateComponentGradients methods for efficient
% jacobian computation of the DEIM approximation. The
% evaluateComponentGradients default implementation uses finite
% differences.
%
% @new{0,6,dw,2012-03-26} Added this class.
%
% This class is part of the framework
% KerMor - Model Order Reduction using Kernels:
% - \c Homepage http://www.agh.ians.uni-stuttgart.de/research/software/kermor.html
% - \c Documentation http://www.agh.ians.uni-stuttgart.de/documentation/kermor/
% - \c License @ref licensing
    
    properties(Dependent)
        PointSets;
    end
    
    properties(Access=private)
        pts = {};
        
        % The x-component selection matrices (precomputed on setting PointSet/AltPointSet)
        S = {};
        
        % Notational vectors for EI-point function argument dependencies
        jrow = {};
        jend = {};
        jself = {};
        deriv = {};
        dfxsel = {};
        T = {};
    end

    methods
        function fx = evaluateComponentSet(this, nr, x, t, mu)
            fx = this.evaluateComponents(this.PointSets{nr},...
                this.jend{nr}, this.jrow{nr}, this.jself{nr}, this.S{nr}*x, t, mu);
        end
        
        function dfx = evaluateComponentSetGradients(this, nr, x, t, mu)
            % Computes the full/reduced gradients of all component
            % functions of the given point set.
            %
            % Uses the template method, whose default implementation is via
            % finite differences.
            dfx = this.evaluateComponentGradients(this.PointSets{nr},...
                    this.jend{nr}, this.jrow{nr}, this.jself{nr},...
                    this.S{nr}*x, t, mu) * this.S{nr};
            % the multiplication by S{nr} from the right is due to the
            % inner derivative (chain rule).
            % this is identity if no projection occured.
            % If this function has been projected, the argument passed to
            % it is Vz, so the component set gradient is right-multiplied
            % by the components of V (which are in S in this case, see
            % setPointSet).
        end
        
        function J = evaluateJacobianSet(this, nr, x, t, mu)
            % Returns the jacobian entries of the point set that have been
            % specified using setPointSet's argument jpd.
            %
            % See also: setPointSet
            
            J = this.evaluateComponentPartialDerivatives(this.PointSets{nr},...
                this.jend{nr}, this.jrow{nr}, this.deriv{nr}, ...
                this.jself{nr}, this.S{nr}*x, t, mu, this.dfxsel{nr});
            % The deriv{nr} contains only derivative indices for non-zero
            % jacobian elements (determined in setPointSet using the
            % JSparsityPattern). Thus, the return values of
            % evaluateComponentPartialDerivatives only are of the size of
            % the actually non-zero jacobian values.
            % The T matrix is a sparse transformation, that places those
            % values into the correct spots with all other values that have
            % been demanded to be evaluated but are actually zero.
            %
            % See setPointSet
            J = this.T{nr} * J;
        end        
               
        function setPointSet(this, nr, pts, jpd)
            % Parameters:
            % pts: A row vector with the desired points @type rowvec<integer>
            % jpd: ("Jacobian Partial Derivatives") A cell array of size
            % equal to the number of points. Each cell contains the indices
            % for which the partial derivatives of the corresponding
            % component function will be computed when calling
            % evaluateJacobianSet. @type cell
            
            if nr > 4
                warning('KerMor:Devel',['Point set numbering seems to ' ...
                    'be used in a different context. 1-4 are safe to work '...
                    'with at this stage, make sure nothing gets overridden.']);
            end
            % Ensure row vectors
            if size(pts,1) > 1
                pts = reshape(pts,1,[]);
            end
            if length(unique(pts)) ~= length(pts)
                error('Points have to be unique.');
            end
            
            this.pts{nr} = pts;
            
            jr = []; js = logical.empty(0,1);
            je = zeros(1,length(pts));
            SP = this.JSparsityPattern;
            % Jacobian extras
            if nargin == 4
                deri = [];
                full_mapping = [];
                requested_len = 0;
                dfx_sel = sparse(length(pts),0);
            end
            for i=1:length(pts)
                sprow = SP(pts(i),:);
                inew = find(sprow);
                jr = [jr inew];%#ok
                js = [js inew == pts(i)];%#ok
                je(i) = length(jr);
                % Jacobian extras
                if nargin == 4
                    des_der = jpd{i};
                    % Select elements of sparsity pattern that have been
                    % requested to be evaluated on evaluateJacobianSet
                    full_mapping = [full_mapping sprow(des_der)];%#ok
                    % deri contains the accumulated indices of 
                    % jacobian entries that are nonzero and thus make sense
                    % to evaluate.
                    [~, dpos, matchidx] = intersect(des_der, inew);
                    % Take the match indices, but sort them in the order
                    % the elements occur in jpd{i} to maintain correct
                    % ordering.
                    [~, sidx] = sort(dpos);
                    pos = matchidx(sidx);
                    
%                     pos1 = jpd{i}(deriv_elem);
                    if ~isempty(pos)
                        if i==1
                            offs = 0;
                        else
                            offs = je(i-1);
                        end    
                        deri = [deri pos+offs];%#ok
                    end
                    % Sum up the total length for later transformation
                    requested_len = requested_len + length(des_der);
                    
                    % Augment dfx selection matrix (only needed for default
                    % finite differences implementation)
                    dfx_sel(i,(end+1):(end+length(inew))) = 1;%#ok
                end
            end
            this.jrow{nr} = jr;
            this.jself{nr} = js;
            this.jend{nr} = je;
           
            % Compose x-entry selection matrix
            len = je(end);
            sel = jr(1:len);
            if ~isempty(this.V)
                this.S{nr} = this.V(sel,:);
            else
                this.S{nr} = sparse(1:len,sel,ones(len,1),len,this.XDim);
            end
            
            % Extras for jacobian evaluations
            this.deriv{nr} = [];
            this.T{nr} = [];
            if nargin == 4
                this.deriv{nr} = deri';
                % Find all the indices of the full mapping record that are
                % nonzero
                at = find(full_mapping);
                % Create a sparse transformation matrix, that assigns the
                % possibly nonzero jacobian entries returned by
                % evaluateComponentPartialDerivatives to their correct spot
                % according to the initially demanded derivatives (this
                % inserts zeros everywhere). If no zero jacobian entries
                % have been specified in setPointSet this is the identity
                % matrix.
                this.T{nr} = sparse(at,1:length(at),ones(length(at),1),...
                    requested_len,length(at));
                % Store convenience dfx selection matrix
                this.dfxsel{nr} = logical(dfx_sel);
            end
        end
        
        function target = project(this, V, W, target)
            if nargin < 4
                target = this.clone;
            end
            target = project@dscomponents.ACoreFun(this, V, W, target);
            % In case the point sets are not created newly: update the
            % current selection matrices
            for i=1:length(this.S)
                if ~isempty(this.S{i})
                    target.S{i} = this.S{i}*V;
                end
            end
        end
        
        function copy = clone(this, copy)
            copy = clone@dscomponents.ACoreFun(this, copy);
            copy.pts = this.pts;
            copy.S = this.S;
            copy.jrow = this.jrow;
            copy.jend = this.jend;
            copy.jself = this.jself;
            copy.deriv = this.deriv;
            copy.dfxsel = this.dfxsel;
            copy.T = this.T;
        end
        
        function psets = get.PointSets(this)
            psets = this.pts;
        end
        
        function res = test_ComponentEvalMatch(this, dim, pdim)
            % Tests if the local implementation of
            x = rand(dim,1);
            mu = rand(pdim,1);
            t = rand;
            fx = this.evaluate(x, t, mu);
            oldpts = [];
            if ~isempty(this.PointSets)
                oldpts = this.PointSets{1};
            end
            
            nsets = 3;
            s = RandStream('mt19937ar','Seed',2);
            setsizes = randi(size(fx,1), nsets, 1);
            sets = cell(nsets,1);
            for i = 1:length(setsizes)
                sets{i} = unique(s.randi(size(fx,1),1,setsizes(i)));
            end
            % Add an extra set with full size
            sets{end+1} = 1:size(fx,1);
            res = true;
            for idx=1:length(sets)
                set = sets{idx};
                this.setPointSet(1, set);
                fxc = this.evaluateComponentSet(1, x, t, mu);
                tmp = fx(set);
                err = abs((tmp-fxc)./tmp);
                err = err(tmp ~= 0);
                d = max(err);
                lres = isempty(d) || d < sqrt(eps);
                if ~lres
                    fprintf('Comp eval to full eval max rel difference: %e\n',full(d));
                end
                res = res && lres;
            end
            if ~isempty(oldpts)
                this.setPointSet(1,oldpts);
            end
        end
    end
    
    methods(Access=protected)
        function dfx = evaluateComponentGradients(this, pts, ends, idx, self, x, t, mu)
            % Default implementation of gradient computation via finite
            % differences.
            %
            % Override in subclasses for more performance if direct
            % derivative information is available.
            %
            % Return values:
            % dfx: A length(pts) x size(x,1) matrix containing the
            % non-zero elements of the gradients of each component function
            % specified by pts. @type matrix<double>
            dt = sqrt(eps);
            d = size(x,1);
            X = repmat(x,1,d); T = repmat(t,1,d); MU = repmat(mu,1,d);
            I = speye(d,d)*dt;
            dfx = (this.evaluateComponents(pts, ends, idx, self, X+I, T, MU) ...
                - this.evaluateComponents(pts, ends, idx, self, X, T, MU))/dt;
        end
        
        function dfx = evaluateComponentPartialDerivatives(this, pts, ends, idx, deriv, self, x, t, mu, dfxsel)
            dt = sqrt(eps);
            d = length(deriv);
            X = repmat(x,1,d); T = repmat(t,1,d); MU = repmat(mu,1,d); %#ok<*PROP>
            I = sparse(deriv,1:d,ones(1,d),size(x,1),d)*dt;
            dfx = (this.evaluateComponents(pts, ends, idx, self, X+I, T, MU) ...
                - this.evaluateComponents(pts, ends, idx, self, X, T, MU))/dt;
            dfx = dfx(dfxsel(:,deriv));
        end
    end
    
    methods(Abstract)
        % This is the template method that actually evaluates the
        % components at given points and values.
        %
        % @attention This method must be able to handle vector-arguments
        % for `x,t,mu`!
        evaluateComponents(this, pts, ends, idx, self, x, t, mu);
    end
end