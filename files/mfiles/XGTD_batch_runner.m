clc;clear all;

% Define Constants
x1 = 25;
x2 = 75; % Reciver maximum X-axis location (50[m])
dx = 25; % Reciver X-axis location step size (25[m])
if x1 > x2
    dx=-dx;
end

% Paths to main XGTD Project file (*.xgtd) and Trasnmitters and Recivers file (*.txrx)
xgtdFilePath = 'E:\files\xgtd\test2\test2.xgtd';
txrxFilePath = 'E:\files\xgtd\test2\test2.txrx';

try
    steps = (x2-x1)/dx+1; % total number of iterations/runs
    xRx=(x1:dx:x2);

    % Parse files
    [xgtdFilename, saBlocks, saParameters, xgtdSplit] = parseFile(xgtdFilePath);
    [txrxFilename, txrxBlocks, txrxParameters, txrxSplit] = parseFile(txrxFilePath);
    
    % Check for empty blocks
    if isempty(saBlocks)
        fprintf('No Study Area blocks found in file ''%s''\n',xgtdFilename);
        return;
    elseif isempty(txrxBlocks)
        fprintf('No Tx/Rx blocks found in file ''%s''\n',txrxFilename);
        return;
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
                return;
        elseif isempty(r)
                fprintf('No Receiver block found\n');
                return;
        elseif isempty(t)
                fprintf('No Transmitter block found\n');
                return;
        else
            if SAcount > 1
                % Set all SA blocks status to inactive
                saBlocks = regexprep(saBlocks,'^(active)','inactive','lineanchors');
            end
            if TXRXcount > 2
                % Set all Tx/Rx sets blocks status to inactive
                txrxBlocks = regexprep(txrxBlocks,'^(active)','inactive','lineanchors');
            end
        
            % Set the status of first transmitter and receiver sets & first manual SA block to 'active'
            saBlocks(m) = regexprep(saBlocks(m),'^(inactive)','active','lineanchors');
            txrxBlocks([t,r]) = regexprep(txrxBlocks([t,r]),'^(inactive)','active','lineanchors');
        
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
            xSA(:, ind) = repmat(xRx+SApadding, numel(ind),1)';
            % Assign the new X coordinates to the vertices
            saParametersNew.vertex1 = mat2cell([xSA(:,1) ySA(:,1) zSA(:,1)], ones(1, steps));
            saParametersNew.vertex2 = mat2cell([xSA(:,2) ySA(:,2) zSA(:,2)], ones(1, steps));
            saParametersNew.vertex3 = mat2cell([xSA(:,3) ySA(:,3) zSA(:,3)], ones(1, steps));
            saParametersNew.vertex4 = mat2cell([xSA(:,4) ySA(:,4) zSA(:,4)], ones(1, steps));
        
            % Update the RX block coordinates
            rxParametersNew.x(:) = num2cell(xRx,1);
        
            % Update the Collection Radius for each iteration/x-location
            W = max(unique(ySA(1,:))) - min(unique(ySA(1,:)));   % Study Area distance along Y-axis (fixed) [m]
            H = saParameters.zmax{m} - saParameters.zmin{m}; % Study Area distance along Z-axis (fixed) [m] (zmax-zmin)
            RaySpacing = 0.25 * pi/180; % Ray Spacing = 0.25°
            L=xRx+SApadding;  %L=[X(:)]+SApadding   % Study Area distance along X-axis (relative to Receiver coordinate xRX) [m]
            MaxSA_Diag = sqrt(L.^2 + W.^2 + H.^2); % Max_Study_Area_Diagonal_Distance is the diagonal of the Study Area boundary around all Features, Transmitters, and Receivers in the project view (cuboid)
            rxParametersNew.radius(:) = num2cell(MaxSA_Diag*RaySpacing);    % Calculate Collection Radis

            rxParametersNew.progress(:) = {'Pending'};
        
            % Initialize arrays to store the command outputs & logs
            cmdStatus = cell(steps,1);
            cmdOut = cell(steps,1);
            logs = strings(size(cmdStatus'));

            % Initialize arrays to store the time stamps
            startTime = cell(steps, 1);
            endTime = cell(steps, 1);
            elapsedTime = cell(steps, 1);

            % Display the number of runs
            fprintf('\nRunning XGTD computation process for %d runs...\n',steps);
            
            % Create a progress bar
            h = waitbar(0,'Please wait...');
            
            % Create a figure for the plot
            figure;
            hold on;
            xlabel('Receiver Location (m)');
            ylabel('Collection Radius (m)');
            title('Collection Radius vs Receiver Location');
            grid on;

            for i = 1:steps
                rxParametersNew.progress{i} = 'Running...';
                % Update the progress bar by displaying the number of current run
                waitbar(i/steps,h,sprintf('Running XGTD calculation engine for SA %d…', i));
                % Plot the collection radius vs receiver location
                plot(rxParametersNew.x{i}, rxParametersNew.radius{i}, 'o');
                legend(rxParametersNew.name{:});
                drawnow;

                % Update the SA block with the modified values
                saBlocks(m) = regexprep(saBlocks(m), ...
                ['(.*?)' saTemp.name{1} '(.*?)' num2str(saTemp.id{1}) '(.*?^)' sprintf('%g %g %g\r\n',cell2mat(saTemp{1,9:12})) '(.*?)'], ...
                ['$1' saParametersNew.name{i} '$2' num2str(saParametersNew.id{i}) '$3' sprintf('%g %g %.g\r\n',cell2mat(saParametersNew{i,9:12})) '$4'],'lineanchors');
                % Update the Tx/Rx block with the modified values
                txrxBlocks(r) = regexprep(txrxBlocks(r), ...
                ['(.*?)' txrxTemp.name{1} '(.*?)' num2str(txrxTemp.id{1}) '(.*?^)' sprintf('%.15f',txrxTemp.x{1}) '(.*?)' num2str(txrxTemp.radius{1},"%.5f") '(.*?)'], ...
                ['$1' rxParametersNew.name{i} '$2' num2str(rxParametersNew.id{i}) '$3' sprintf('%.15f',rxParametersNew.x{i}) '$4' num2str(rxParametersNew.radius{i},"%.5f") '$5'],'lineanchors');
    
                % Join the modified blocks into a new string
                xgtdFileContentNew = join([xgtdSplit(1); reshape([saBlocks; xgtdSplit(2:end)], [], 1)], '');
                txrxFileContentNew = join([txrxSplit(1); reshape([txrxBlocks; txrxSplit(2:end)], [], 1)], '');
    
                % Write the updated contnet back to file
                writelines(xgtdFileContentNew,xgtdFilePath);
                writelines(txrxFileContentNew,txrxFilePath);
   
                % Execute the command with the file name as an argument to run XGTD calculation engine each iteration
                % If command is successful, status is 0. Otherwise, nonzero integer
                xgtdCommand = ['"C:\Program Files\Remcom\XGtd 3.1.2.0\bin\calc\calcgtd.exe" --project="' xgtdFilePath '"'];
                
                % Record the start time of the command execution and add the time stamps to the updated parameters table
                startTime{i} = datetime('now');
                rxParametersNew.startTime{i} = char(startTime{i});
                [cmdStatus{i},cmdOut{i}] = system(xgtdCommand,'-echo'); % to ommit execution display: [cmdStatus{i},cmdOut{i}] = system(xgtdCommand);
                endTime{i} = datetime('now');
                rxParametersNew.endTime{i} = char(endTime{i});
                elapsedTime{i} = between(startTime{i},endTime{i});
                rxParametersNew.elapsedTime{i} = char(elapsedTime{i});
    
                % Log messages for each iteration
                logs(i) = sprintf('Run #%d logs:------------------------------------------------\n', i);
                if  cmdStatus{i} == 0
                    status = 'successful';
                    rxParametersNew.progress{i} = 'Completed';
                else
                    status = 'not successful';
                    rxParametersNew.progress{i} = 'Failed';
                end
                logs(i) = logs(i) + sprintf('Command Status: %d = (%s)\n', cmdStatus{i},status);
                logs(i) = logs(i) + sprintf('Command Output:\n%s\n------------------------------------------------------------\n', cmdOut{i});
            
                % Store the updated receiver set parameters in the temp table
                saTemp = saParametersNew(i,:);
                txrxTemp = rxParametersNew(i,:);
            end
            % Close the progress bar
            close(h);

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
    % Extract file name and extension
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
        [blocks,parameters,split] = regexp(fileContent,'begin_<points> (?<name>[^\r\n]+).*?(?<id>\d+)\s+(?<status>\w+).*?(?#location)(?<x>\S+)\s(?<y>\S+)\s(?<z>\S+).*?begin_<(?<type>transmitter|receiver)>(?:(?!begin_<points>|collection_radius).)*(?:collection_radius )?(?<radius>[\d\.]*)?(?:(?!begin_<points>).)*end_<points>','match','names','split');
        % Convert the matched parameters strcuture to table
        parameters = struct2table(parameters,"AsArray",true);
        % Convert numeric variables from string to numeric
        parameters{:,{'id','x','y','z','radius'}} = cellfun(@str2num,parameters{:, {'id','x','y','z','radius'}},'UniformOutput',false);
    end
end
