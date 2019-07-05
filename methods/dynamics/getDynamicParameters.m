
function [Msubs, dynamicParamsReturn, a] = getDynamicParameters(M,q, exceptionTerms)
% Very empiric (/messy) method to extract dynamic parameters from the Inertia
% matrix in robot dynamics. Based on grouping terms.

% q = vector of q parameters (symbolic)
% q = [q1, q2, ... , qn]
% exceptionTerms: literals or expressions that are known and should be kept
% outside the dynamic parameters, like links length. 
% exceptionTerms = [l(2)] 

% created by Andr�s Arciniegas (06/2019)
disp(">> Getting dynamic coefficients. Might take a while...")
[n,cols] = size(M); % square matrix
Msubs = M;
aa = sym('aa', [1,20]); % 20 is a random approximation. Depends on M. For RR Robot is around 5
dynamicParams = [];
nparams = 0; % Number of replacements
for iter = 1:2
    % Get constants
    indepen = {};
    depen ={};
    dynParams = [];
    for k = 1:n % Main loop
        for j = k:cols
            dep=[]; % Independent terms
            indep=[]; % Coefficient of some q
            % expand is used to avoid (1/2)*(cos(q1) + cos(q2)) = 1 term. 
            % It has to be expanded
            childs = children(expand(Msubs(k,j))+1); %% add 1 because it has to be more than 1 term to split]
            for i=1:length(childs)-1
                child = childs(i);
                [child, keepGoing] = removeExceptionsInTerm(child, exceptionTerms, iter, nparams, aa);
                if ~keepGoing
                    continue
                end
                    if(has(child,q))
                        if has(childs(i),cos(q))
                            for h =1:n % This is to deal with cases like m3*q3*cos(q2), where, if I replace directly 0 in cosine, the other q becomes zero too, making it all zero
                                if has(child,cos(q(h))) 
                                    child = subs(child,q(h),0) ;
                                end
                            end

                            child = subs(child,q,ones(n,1)); % At this point it's free to replace by one
                            if child ~= 1 % In case we replace cosine and a '1' is left, discard it. (No coefficient)
                               dep = [dep, child]; 
                            end                
                        elseif has(childs(i),sin(q))
                            for h =1:n
                                if has(child,sin(q(h))) 
                                    child = subs(child,q(h),pi/2) ;
                                end
                            end
                            child = subs(child,q,ones(n,1)) ;
                            if child ~= 1 % should be 0, but we added a 1 element. In case we replace cosine and a one is left, discard it. (No coefficient)
                               dep = [dep, child]; 
                            end                      
                        else
                            child = subs(child,q,ones(n,1)) ;
                            dep = [dep, child];
                        end
                    else
                        indep = [indep, child];
                    end
            end
            if length(dep) == 0 
                % These are dynamic coefficients for sure, since they
                % appear independently on the M matrix
                if sum(indep) ~= 0
                    dynParams = [dynParams, sum(indep)]   ; 
                end
            end
            depen = [depen, dep];
            indepen{k,j} = indep;
        end
    end
    % Totally independent terms are replaced by an 'a' term.
    % Also the coefficients of q dependent terms
    if iter == 1
        depenSubs = removeTermsSelfContained(depen); 
        params = [dynParams depenSubs];
        %Selects only the parameters with only one term, 
        params1term = cellfun(@length, children(params+ ones(size(params)))) <= 2
        
        %Sort the parameters by length
        [~,I] = sort(cellfun(@length, children(params(params1term))),'descend');
        params1 = params(params1term);
        %First put the composed parameters (m1+m2), and then the single
        %parameters terms (d*m3)
        params = [params(~params1term), params1(I)];
        
        nparams = length(params);
        dynamicParams = params;
        for i = 1:nparams
        %    dynamicParams = [dynamicParams params(i)];
            Msubs = subs(expand(Msubs), params(i), aa(i));
        end
        disp('MSubs First iteration')
        Msubs
    end
    
    if iter == 2
        % Substitute independent variables
        indepSubs = [];
        for i = 1: numel(indepen)
            if length(indepen{i}) > 1
                indepSubs = [indepSubs, sum((indepen{i}))];
            end
        end
        %params = indepSubs;
        for i =1:length(indepSubs)
            indepTerm = subs(indepSubs(i), aa(1:nparams), dynamicParams); % Replace any 'aa' term previously assigned
            dynamicParams = [dynamicParams indepTerm];
            Msubs = subs(expand(Msubs), indepSubs(i), aa(nparams+i));
        end
        disp('MSubs second iteration (before re-replacement)')
        Msubs
        % Finally, reorder the constants and assign the correct order to the
        % parameters.
        % This is done because they might have been replaced with another
        % 'a' term in the process. And some of them are not used anymore.
        
        max_a = nparams+length(indepSubs);
                
        dynamicParamsReturn = [];
        aa_replace = [];
                
        for kk = 1: max_a
            % If contains at least one term of that 'aa' element, save the
            % element
            if sum(has(Msubs, aa(kk)),'All') > 0 
                dynamicParamsReturn = [dynamicParamsReturn, dynamicParams(kk)];
                aa_replace = [aa_replace, aa(kk)];
            end
        end
        dynamicParamsReturn = dynamicParamsReturn.' ;% Vertical vector form
        a = sym('a',[1, length(dynamicParamsReturn)]);
        
        Msubs = subs(Msubs, aa_replace, a);
        Msubs = simplify(Msubs)
    end
end

end
function [termReturn, keepGoing]= removeExceptionsInTerm(term, exceptionTerms, iteration, nparams, aa)
    % nparams = number of replaced parameters
    if iteration == 1
        termReturn = subs(term, exceptionTerms, ones(1,length(exceptionTerms))); % Replaces the exception terms by 1
        keepGoing = 1 ;% Even if there are replacements, the algorithm should continue
    end
    
    if iteration == 2 % Already passed by one replacement
        for hh = 1:nparams
            for xx = 1:length(exceptionTerms)
                % It should enter here only if the term has a variable that
                % has been replaced, and has exception term, like a4*l2.
                % This term should be kept just as it is.
                
                if (has(term,aa(hh)) && has(term,exceptionTerms(xx)))
                    keepGoing = 0; % No further replacements should be done with this term
                    termReturn = term; % Just to put some output, but not needed.
                    return
                end
            end
        end
        
        % if the loop ended, means that the term is ok, and should continue
        termReturn = term;
        keepGoing = 1;
        
        % Finally, the linear parametrization if found.
        %Ym = getLinearParametrization(
    end
    
%     for jj = 1:length(exceptionTerms)
% %         for ii = 1: length(subterms)
% %             if ~isequaln(subterms(ii),exceptionTerms(jj))
% %                 returnTerms = [returnTerms subterms(ii)]
% %             end
% %         end
%         returnTerms = [returnTerms deleteSymbolicTerm(subterms, exceptionTerms(jj))]
%     end
%     termReturn = prod(unique(returnTerms))
end

