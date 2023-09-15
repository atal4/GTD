clc;clear all;

% Define Constants
xMax = 75; % Reeciver maximum X-axis location (50[m])
dx = 25; % Reeciver X-axis location step size (25[m])

% Paths to main XGTD Project file (*.xgtd) and Trasnmitters and Recivers file (*.txrx)
xgtdFilePath = 'E:\files\xgtd\test2\test2.xgtd';
txrxFilePath = 'E:\files\xgtd\test2\test2.txrx';

% if isfile(xgtdFilePath) && isfile(txrxFilePath)
%     runXGTD(xgtdFilePath, txrxFilePath, X_MAX, DX, SA_PADDING, RAY_SPACING);
% else
%     fprintf('One or both input files do not exist or are not accessible.\n')
%     abort;
% end

try
    steps = xMax/dx; % total number of iterations/runs

    % Parse files
    [xgtdFilename, saBlocks, saParameters, xgtdSplit] = parseFile(xgtdFilePath);
    [txrxFilename, txrxBlocks, txrxParameters, txrxSplit] = parseFile(txrxFilePath);
    
    % Check for empty blocks
    if isempty(saBlocks)
        fprintf('No Study Area blocks found in file ''%s''\n',xgtdFilename);
    elseif isempty(txrxBlocks)
        fprintf('No Tx/Rx blocks found in file ''%s''\n',txrxFilename);
    else
        % Find indices of Study Area blocks
        saAutoIndices = find([saParameters.auto{:}] == 1);
        saManualIndices = find([saParameters.auto{:}] == 0);
        
        % Find indices of Tx/Rx blocks
        TxIndices = find(txrxParameters.type == "transmitter");
        RxIndices = find(txrxParameters.type == "receiver");
        
        % Total count of blocks
        SAcount = height(saParameters);
        TXRXcount = height(txrxParameters);
        
        % Display blocks' parameters
        fprintf('\n%d Study Area(s) found in file ''%s'': %d auto Study Area(s) and %d manual Study Area(s)\n\n',SAcount,xgtdFilename,numel(saAutoIndices),numel(saManualIndices));
        disp(saParameters);
        fprintf('\n%d Tx/Rx block(s) found in file ''%s'': %d transmitter set(s) and %d receiver set(s)\n\n',TXRXcount,txrxFilename,numel(TxIndices),numel(RxIndices));
        disp(txrxParameters);
        
        % Get index of the first manual SA block, transmitter, and receiver blocks
        [~,~,m] = find(saManualIndices,1);
        [~,~,t] = find(TxIndices,1);
        [~,~,r] = find(RxIndices,1);
        
        % Look for 1st manual SA blocks and edit block's parameters
        if isempty(m)
                fprintf('No manual Study Area block found\n');
        elseif isempty(r)
                fprintf('No Receiver block found\n');
        elseif isempty(t)
                fprintf('No Transmitter block found\n');
        else
            if SAcount > 1
                % Set all SA blocks status to inactive
                saBlocks = setBlockStatus(saBlocks,'inactive');
            end
            if TXRXcount > 2
                % Set all Tx/Rx sets blocks status to inactive
                txrxBlocks = setBlockStatus(txrxBlocks,'inactive');
            end
        
            % Set the status of first transmitter and receiver sets & first manual SA block to 'active'
            saBlocks(m) = setBlockStatus(saBlocks(m),'active');
            txrxBlocks([t,r]) = setBlockStatus(txrxBlocks([t,r]),'active');
        
            % Create a table to store the updated receiver set parameters to keep track on changes
            saParametersNew = repmat(saParameters(m,:),steps,1);
            rxParametersNew = repmat(txrxParameters(r,:),steps,1);
        
            % Create a temp table to be used for the replacement process
            saTemp = saParameters(m,:);
            txrxTemp = txrxParameters(r,:);
            
            % Update the blcoks parameters
            saParametersNew.name = cellfun(@(x) sprintf('SA %d',x),num2cell(1:steps),'UniformOutput',false)'; % Update set name
            rxParametersNew.name = cellfun(@(x) sprintf('Rx %d',x),num2cell(1:steps),'UniformOutput',false)'; % Update set name
        
            saParametersNew.status(:) = {'active'};  % set Updated SA blocks status to active
            rxParametersNew.status(:) = {'active'};  % set all Updated Rx sets status to active
        
            saParametersNew.id(:) = num2cell(m:(steps+m-1)); % Update set id
            rxParametersNew.id(:) = num2cell(r:(steps+r-1)); % Update set id
        
            % Update the SA block coordinates
            xSA = repmat([saParameters.vertex1{m}(1), saParameters.vertex2{m}(1), saParameters.vertex3{m}(1), saParameters.vertex4{m}(1)], steps, 1);
            ySA = repmat([saParameters.vertex1{m}(2), saParameters.vertex2{m}(2), saParameters.vertex3{m}(2), saParameters.vertex4{m}(2)], steps, 1);
            zSA = repmat([saParameters.vertex1{m}(3), saParameters.vertex2{m}(3), saParameters.vertex3{m}(3), saParameters.vertex4{m}(3)], steps, 1);
            % Find the maximum X value and its indices
            maxX = max(unique(xSA));
            ind = find(xSA(1,:) == maxX);
            % Update the X coordinates with the new value
            SApadding = 0.25; % Study Area padding
            xSA(:, ind) = repmat((25*(1:steps))+SApadding, numel(ind),1)';
            % Assign the new X coordinates to the vertices (maybe we can use 'parfor')
            saParametersNew.vertex1 = mat2cell([xSA(:,1) ySA(:,1) zSA(:,1)], ones(1, steps));
            saParametersNew.vertex2 = mat2cell([xSA(:,2) ySA(:,2) zSA(:,2)], ones(1, steps));
            saParametersNew.vertex3 = mat2cell([xSA(:,3) ySA(:,3) zSA(:,3)], ones(1, steps));
            saParametersNew.vertex4 = mat2cell([xSA(:,4) ySA(:,4) zSA(:,4)], ones(1, steps));
        
            % Update the RX block coordinates
            xRX = repmat(25*(1:steps),1);
            yRx = repmat([txrxParameters.location{r}(2)], steps, 1);
            zRX = repmat([txrxParameters.location{r}(3)], steps, 1);
            % Assign the new X coordinates to the vertices
            rxParametersNew.location = mat2cell([xRX(:) yRx(:) zRX(:)], ones(1, steps));
        
            % Update the Collection Radius for each iteration/x-location
            W = max(unique(ySA(1,:))) - min(unique(ySA(1,:)));   % Study Area distance along Y-axis (fixed) [m]
            H = saParameters.zmax{m} - saParameters.zmin{m}; % Study Area distance along Z-axis (fixed) [m] (zmax-zmin)
            RaySpacing = 0.25 * pi/180; % Ray Spacing = 0.25°
            L=xRX+SApadding;  %L=[X(:)]+SApadding   % Study Area distance along X-axis (relative to Receiver coordinate xRX) [m]
            MaxSA_Diag = sqrt(L.^2 + W.^2 + H.^2); % Max_Study_Area_Diagonal_Distance is the diagonal of the Study Area boundary around all Features, Transmitters, and Receivers in the project view (cuboid)
            rxParametersNew.radius(:) = num2cell(MaxSA_Diag*RaySpacing);    % Calculate Collection Radis
        
            % Initialize arrays to store the command outputs & logs
            cmdStatus = cell(steps,1);
            cmdOut = cell(steps,1);
            logs = strings(size(cmdStatus'));
            for i = 1:steps
                % Update the SA block with the modified values
                saBlocks(m) = regexprep(saBlocks(m), ...
                ['(.*?)' saTemp.name{1} '(.*?)' num2str(saTemp.id{1}) '(.*?\r\n)' sprintf('%g %g %g\r\n',cell2mat(saTemp{1,9:12})) '(.*?)'], ...
                ['$1' saParametersNew.name{i} '$2' num2str(saParametersNew.id{i}) '$3' sprintf('%g %g %.g\r\n',cell2mat(saParametersNew{i,9:12})) '$4'],'ignorecase');
                % Update the Tx/Rx block with the modified values
                txrxBlocks(r) = regexprep(txrxBlocks(r), ...
                ['(.*?)' txrxTemp.name{1} '(.*?)' num2str(txrxTemp.id{1}) '(.*?\r\n)' sprintf('%.15f %.15f %.15f',txrxTemp.location{1}) '(.*?)' num2str(txrxTemp.radius{1},"%.5f") '(.*?)'], ...
                ['$1' rxParametersNew.name{i} '$2' num2str(rxParametersNew.id{i}) '$3' sprintf('%.15f %.15f %.15f',rxParametersNew.location{i}) '$4' num2str(rxParametersNew.radius{i},"%.5f") '$5'],'ignorecase');
    
                % Join the modified blocks into a new string
                xgtdFileContentNew = join([xgtdSplit(1); reshape([saBlocks; xgtdSplit(2:end)], [], 1)], '');
                txrxFileContentNew = join([txrxSplit(1); reshape([txrxBlocks; txrxSplit(2:end)], [], 1)], '');
    
                % Write the updated contnet back to file
                writelines(xgtdFileContentNew,xgtdFilePath);
                writelines(txrxFileContentNew,txrxFilePath);
    
                % Execute the command with the file name as an argument to run XGTD calculation engine each iteration
                % If command is successful, status is 0. Otherwise, nonzero integer
                fprintf('Running XGTD calcuation engine for SA %d...\n', i);
                xgtdCommand = ['"C:\Program Files\Remcom\XGtd 3.1.2.0\bin\calc\calcgtd.exe" --project="' xgtdFilePath '"'];
                [cmdStatus{i},cmdOut{i}] = system(xgtdCommand,'-echo'); % to ommit execution display: [cmdStatus{i},cmdOut{i}] = system(xgtdCommand);
    
                % Log messages for each iteration
                logs(i) = sprintf('Run #%d logs:------------------------------------------------\n', i);
                if  cmdStatus{i} == 0
                    logs(i) = logs(i) + sprintf('Command Status: %d = (successful)\n', cmdStatus{i});
                else
                    logs(i) = logs(i) + sprintf('Command Status: %d (not successful)\n', cmdStatus{i});
                end
                logs(i) = logs(i) + sprintf('Command Output:\n%s\n------------------------------------------------------------\n', cmdOut{i});
            
                % Store the updated receiver set parameters in the temp table
                saTemp = saParametersNew(i,:);
                txrxTemp = rxParametersNew(i,:);
            end
            if all([cmdStatus{:}] == 0)
                fprintf('XGTD computation process has finished running %d runs successfully.\n',steps);
            else
                fprintf('XGTD computation process has finished running %d runs with error.\n',steps);
            end
            % Write logs to file
            writelines(logs,[xgtdFilePath, '.m.log']);
           
            % Display the updated parameters
            fprintf('\nUpdated blocks:\n');
            disp(saParametersNew);
            disp(rxParametersNew);
        end
    end
catch exception
    % Log the exception information
    fprintf('Error: %s\n', exception.message);
    fprintf('Exception Identifier: %s\n', exception.identifier);
    fprintf('Exception Stack Trace:\n');
    disp(exception.getReport);
    
    % Restore Backup
    fprintf('Restoring the original files from backup...\n');
    copyfile([xgtdFilePath, '.m.bak'], xgtdFilePath);
    copyfile([txrxFilePath, '.m.bak'], txrxFilePath);
end

% Function to parse files
function [fileName, blocks, parameters, split] = parseFile(filePath)
    % Define Constants
    [~,name,ext] = fileparts(filePath);
    fileName = [name ext];
    
    % Read file content
    fileContent = fileread(filePath);
    
    % Create a backup of the original file
    copyfile(filePath, [filePath, '.m.bak']);
    
    % Extract blocks and Parameters
    if ext == ".xgtd"
        [blocks,parameters,split] = regexp(fileContent,'begin_<studyarea> (?<name>[^\r\n]+).*?(?<id>\d+)\s+(?<status>\w+).*?autoboundary (?<auto>\d+).*?longitude (?<longitude>\S+)\s+latitude (?<latitude>\S+).*?zmin (?<zmin>\S+)\s+zmax (?<zmax>\S+).*?nVertices\s\d\s+(?<vertex1>\S+\s\S+\s\S+)\s+(?<vertex2>\S+\s\S+\s\S+)\s+(?<vertex3>\S+\s\S+\s\S+)\s+(?<vertex4>\S+\s\S+\s\S+).*?end_<studyarea>','match','names','split');
        % Convert the matched parameters strcuture to table
        parameters = struct2table(parameters,"AsArray",true);
        % Convert numeric variables from string to numeric
        parameters{:,{'id','auto','longitude','latitude','zmin','zmax','vertex1','vertex2','vertex3','vertex4'}} = cellfun(@str2num,parameters{:, {'id','auto','longitude','latitude','zmin','zmax','vertex1','vertex2','vertex3','vertex4'}},'UniformOutput',false);
    elseif ext == ".txrx"
        [blocks,parameters,split] = regexp(fileContent,'begin_<points> (?<name>[^\r\n]+).*?(?<id>\d+)\s+(?<status>\w+).*?(?<location>\S+\s\S+\s\S+).*?begin_<(?<type>transmitter|receiver)>(?:(?!begin_<points>|collection_radius).)*(?:collection_radius )?(?<radius>[\d\.]*)?(?:(?!begin_<points>).)*end_<points>','match','names','split');
        % Convert the matched parameters strcuture to table
        parameters = struct2table(parameters,"AsArray",true);
        % Convert numeric variables from string to numeric
        parameters{:,{'id','location','radius'}} = cellfun(@str2num,parameters{:, {'id','location','radius'}},'UniformOutput',false);
    end
end

% Function to set activate/desactivate blocks
function block = setBlockStatus(block,status)
    % Set block status to 'active' or 'inactive'
    block = regexprep(block,'^(active|inactive)',status,'lineanchors');
end

function y = readInput()
    var = inputname(1);
    y = input(['Enter the value of ' var ' : ']);
    if (y<0)
        y = readInput(x);
    end
end
