classdef SQLiteImageDataBase < handle
%     Interface class to a SQLite database storing the location
%     of images and the hierachy among the image.
%     Images are copied into a single folder called SourceImages
%     with no subfolder structure.

    %{
    Stephan Meyer 2016 fuschro@gmail.com
    https://github.com/ninehundred1
    
    
    Matlab Handle Class to connect to an SQLite database for storing images
    in tree structure with metadata attached to each image. The images are
    copied into a separate folder and only the paths are stored in the database
    together with the metadata.
    The database can be queried for metadata parameter ranges and the image
    paths gets returned.
     
    FOLLOW BELOW AS SETUP ***********************
    1. download SQLite3 (I used Sqlite 3.11)
    https://www.sqlite.org/download.html
    
    2. download driver sqlite-jdbc-3.8.11.2.jar from
    https://bitbucket.org/xerial/sqlite-jdbc/downloads
    and change the path below at varible YOUR_COMPUTER_JAR_FILE to match
    the location where you saved it
    eg 'C:\Users\Meyer\AppData\Roaming\MathWorks\MATLAB\R2012a\sqlite-jdbc-3.8.11.2.jar'
    
    3. make a folder in 'C:' called 'sqlite_dbs' where your databases are
    stored
    ('C:\sqlite_dbs\')
    
    4. to view the data outside of Matlab, download SQLite browser from
    http://sqlitebrowser.org/
    
    for more help:
    http://www.mathworks.com/help/database/ug/sqlite-jdbc-windows.html
    

    EXAMPLE USE: *********************************
    %Initialize Database and Table
    db = SQLiteImageDataBase('koff', 'Experiment_1');
    
    %Add images and Metadata to Table with a new name 'Bike_blue' and a
    Subclass of 1 and into the Subset of 2
    db.InsertIntoTable('Bike_blue', 1, 2);
    
    %Query table for parameter ranges
    %Get all entries of this range sorted by Hum_C_score 
    query_return = db.RetrieveEntriesFromTable('Bike_blue2', '0','1',...
    '0.5','0.7' , '0', '2', '0', '-1', '0', '-1','0', 'Hum_C_Score', '50','0')

    %expand the cursor to get data into the Matlab workspace as cell matrix
    the_data = ans.query_return

    %Get one image metadata entry by the file name of image
    current_image_data =
    db.RetrieveSingleEntryByName('patch_id107_7364456323.png').data
    
    %Update Entry by filename (update data 'Times_wrong' to 1002), row 14 is
    %the image name within the image data (can also use eg 
    %'patch_id107_7364456323.png' instead of current_image_data(14)
    db.UpdateEntry(char(current_image_data(14)),'Times_wrong',1002)

    %retrieve the whole image tree the current image belongs to.
    %The tree is based on what was specified in the initial
    %image import as being part of the same tree. Specify with second
    %parameter what you want your tree to be ordered as
    current_tree = 
        db.RetrieveWholeTreeByName(char(current_image_data(14)).data,
        'Hum_C_Score')
    
    %Retrieve image one level up in tree, using Hum_C_Score as tree order
    db.GetImageOneUpInTree(char(current_image_data(14)), 'Hum_C_Score')

    %Retrieve image one level down in tree, using Hum_C_Score as tree order
    db.GetImageOneDownInTree(char(current_image_data(14)), 'Hum_C_Score')
     
    %}
    
    properties(GetAccess='private', SetAccess='private')
        dbName % db Name
        dbTableName %db Table Name
        Connection % SqlConnection object
        dbpath %path to database
        URL %URL
        SourceImageFolderPath
        dbcolnames %db colum names
    end
    
    methods
        %{
        ----Constructor----
        As parameters use the name of database and table as a string
        Args:
            dataBaseName(String) = Name of SQLite database to connect to.
            tableName(String) = Name of SQLite table to connect to.
        %}
        function this = SQLiteImageDataBase(dataBaseName, tableName)
            this.initDB(dataBaseName, tableName);
            this.initImageFolder(this.SourceImageFolderPath);
            %CHANGE LINE BELOW TO ADAPT DB ENTRIES (1/3)
            this.dbcolnames = {'Class','SubClass','Hum_C_Score','Size','Subset','Is_MIRC','Monkey_C_Score',...
                'Times_shown', 'Times_correct', 'Times_wrong', 'Date_last_shown','Date_added', 'Is_Original',...
                'File_name', 'Unique_branchID','Path'};
        end
        
        %---- BELOW ARE THE INTERFACE METHODS----
        function Close(this)
            %{
            ----Close db connection----
            %}
            close(this.Connection);
            disp('connection closed')
        end
        
        function Open(this)
            %{
            ----Open db connection----
            %}
            this.Connection = database(this.dbpath,'','','org.sqlite.JDBC',this.URL);
            if ~isconnection(this.Connection)
                disp(this.dbpath);
                error('MyComponent:noConnection',...
                    'Error. \n Connection failed, check class header for setup instructions.')
            else
                disp('Connection open.')
                disp(['Location: ',this.dbpath])
            end
        end
        
        function InsertIntoTable(this,Class_in, SubClass_in, Subset_in)
            %{
             ---- Make new table with these rows----
            As Parameters use the Image Class as string (eg 'Bike'), the
            Subclass as int (eg 2) and the Subset as int (eg 2).
            Subclass is defined as one branch of a tree (don't use the number
            for other branches, subset is defined as a collection of
            branches that you can then query for (eg if you two subsets,
            you can show only images from subset 1 one week, 2 another
            week.
            Args:
            Class_in(String) = Name of Class you want the image to be in
            (eg 'Bike')
            SubClass_in(int) = Number of SubClass (eg 2, to be understood
            as Bike 2)
            Subset_in(int) = Number of Subset to be in (eg 4, to be part of
            subset 4.
            %}
            folder_path = uigetdir('C:\','Select folder containing stimuli and original.');
            if ~folder_path
                error('no folder selected');
            end
            [pathstr,folder_name,ext] = fileparts(folder_path);
            unique_ID = SQLiteImageDataBase.generate_unique_ID();
            %copy the original to the images folder with a unique ID
            %attached
            try
                ImageSavePath = SQLiteImageDataBase.copyOriginal(unique_ID,folder_name, pathstr, this.SourceImageFolderPath);
                %add the image to database
                dbdata = {Class_in, SubClass_in, -1, -1, Subset_in, 0, -1,...
                    -1, -1, -1, -1, datestr(now,'yyyy-mm-dd HH:MM:SS'), 1, ImageSavePath};
                %insert into db using the columnames defined in constructor
                datainsert(this.Connection,this.dbTableName,this.dbcolnames,dbdata)
                disp('copied orignal.')
            catch
                disp('failed to copied orignal.')
            end
            % Get all subfolders inside folder 'stimuli' as list and import
            files = dir([folder_path,'/stimuli']);
            dirFlags = [files.isdir];
            % Extract only those that are directories.
            subFolders = files(dirFlags);
            for k = 1 : length(subFolders)
                %ignore .. and . folders
                if ~(strcmp(subFolders(k).name,'.')) &&  ~(strcmp(subFolders(k).name,'..'))
                    SQLiteImageDataBase.InsertFolder(unique_ID,[[folder_path,'\stimuli'],'\',subFolders(k).name],...
                        this.SourceImageFolderPath, this.Connection, this.dbTableName, Class_in, SubClass_in, Subset_in, this.dbcolnames);
                end
            end
            %make query to get last 5 entrie rows of data to display in command window
            setdbprefs('DataReturnFormat','cellarray');
            curs = exec(this.Connection,sprintf('select * from %s ORDER BY ROWID DESC LIMIT 5', this.dbTableName),5);
            ret_data = fetch(curs);
            disp('********');
            disp('last 5 rows of new entries:');
            disp(ret_data.Data);
            disp('****done importing images****');
        end
        
        %CHANGE LINES BELOW TO ADAPT DB ENTRIES (3/3) -SEARCH
        function data_curs = RetrieveEntriesFromTable(this, Class_in, SubClass_min, SubClass_max,...
                Hum_C_Score_min, Hum_C_Score_max, Subset_min, Subset_max,...
                Is_MIRC_in, Monkey_C_Score_min, Monkey_C_Score_max, Times_shown_min,...
                Times_shown_max, Sort_By_column, max_entries, Is_original_in)
            
            %{
             ---- Retrieve Entries to db using a query----
            As Parameters use the columns you want to query and the range.
            Eg Subset_min is the min value that gets returned for Subset,
            Subset_max would be the max. All other parameters further
            narrow down the query.
                
            ALL NEED TO BE STRINGS, eg
            curs = db.RetrieveEntriesFromTable('Bike_blue', '0','1', '0.6','0.7' ,
            '0', '2', '0', '-1', '0', '-1','0', 'Hum_C_Score', '50','0'  )

             Returns a cursor object. To access the data, use .data on the
             return (the_data = curs.data;)
                %}
                
                sqlquery = ['SELECT * FROM ',this.dbTableName,...
                    ' WHERE SubClass BETWEEN ',SubClass_min,' AND ',SubClass_max,...
                    ' AND Subset BETWEEN ',Subset_min,' AND ',Subset_max,...
                    ' AND Monkey_C_Score BETWEEN ',Monkey_C_Score_min,' AND ',Monkey_C_Score_max,...
                    ' AND Hum_C_Score BETWEEN ',Hum_C_Score_min,' AND ',Hum_C_Score_max,...
                    ' AND Times_shown BETWEEN ',Times_shown_min,' AND ',Times_shown_max,...
                    ' AND Times_shown BETWEEN ',Times_shown_min,' AND ',Times_shown_max,...
                    ' AND Is_original IS ', Is_original_in,...
                    ' AND Class = ''', Class_in, '''',...
                    ' AND Is_MIRC IS ', Is_MIRC_in,...
                    ' ORDER BY ', Sort_By_column,' DESC LIMIT ',max_entries];
                setdbprefs('DataReturnFormat','cellarray');
                curs = exec(this.Connection,sqlquery);
                data_curs = fetch(curs);
                close(curs);
        end
        
         function updated_entry = UpdateEntry(this, Filename,column_name, new_entry)
              %{
             ---- Update Column in db using Image name as index----
            As Parameters use the filename of the image data you want to 
            change, the columns you want to update and the new value.
                           
            ALL NEED TO BE STRINGS, eg
            curs = db.UpdateEntry(char(current_image(14)),'Times_wrong',1002)
            here current_image is the db entry for the image, so the actual
            image can also be used (as 'patch_id112_7364466787.png')
            Returns a cursor object to the updated single entry. 
            To access the data, use .data on the  return (the_data = curs.data;)
                %}
                whereclause = ['where File_name = ''', Filename, ''''];
                colnames = {column_name};
                new_data = {new_entry};
                update(this.Connection,this.dbTableName,colnames,new_data,whereclause)
                updated_entry = RetrieveSingleEntryByName(this, Filename);
         end
        
        %CHANGE LINES BELOW TO ADAPT DB ENTRIES (3/3) -SEARCH
        function data_curs = RetrieveSingleEntryByName(this, File_name_in)
              %{
             ---- Retrieve db image metadata entry using image file name----
            As Parameters use the filename of the image data you want to 
            retrieve.
                           
            ALL NEED TO BE STRINGS, eg
            curs = db.RetrieveSingleEntryByName(char(current_image(14)))
            here current_image is the db entry for the image, so the actual
            image can also be used (as 'patch_id112_7364466787.png')
            Returns a cursor object to the single entry with all db data. 
            To access the data, use .data on the  return (the_data = curs.data;)
                %}
            
           sqlquery = ['SELECT * FROM ',this.dbTableName,...
                    ' WHERE File_name = ''', File_name_in, ''''];
                setdbprefs('DataReturnFormat','cellarray');
                curs = exec(this.Connection,sqlquery);
                data_curs = fetch(curs);
                close(curs);
        end
        
        function data_curs = RetrieveWholeTreeByName(this, File_name_in, Sort_By_column)
              %{
             ---- Retrieve db complete image tree entry using image file name----
            As Parameters use the filename of the image data you want to 
            retrieve and also the colum to sort the tree by.
                           
            ALL NEED TO BE STRINGS, eg
            curs =
             db.RetrieveWholeTreeByName(char(current_image(14)), 'Hum_C_Score')
            here current_image is the db entry for the image, so the actual
            image can also be used (as 'patch_id112_7364466787.png')
            Returns a cursor object to the complete tree with all db data. 
            To access the data, use .data on the  return (the_data = curs.data;)
                %}
            data_curs = this.RetrieveSingleEntryByName(File_name_in);
            tree_id = data_curs.data(15);
            sqlquery = ['SELECT * FROM ',this.dbTableName,...
                ' WHERE Unique_branchID = ', char(tree_id),...
                ' ORDER BY ', Sort_By_column];
            curs = exec(this.Connection,sqlquery);
            data_curs = fetch(curs);
            close(curs);
        end
        
        function File_name_out = GetImageOneUpInTree(this, File_name_in, Sort_By_column)
              %{
             ---- Retrieve image name of one image up in the tree hierachy.
             The hierachy order column used is defined by Sort_By_column
                           
            ALL NEED TO BE STRINGS, eg
            curs =
              db.GetImageOneUpInTree(char(current_image(14)), 'Hum_C_Score')
            here current_image is the db entry for the image, so the actual
            image can also be used (as 'patch_id112_7364466787.png')
            Returns a filename of the image one further up in the order of 
            Hum_C_Score.  
            If the image is the top leve, -1 gets returned.
                %}
            
            whole_tree = this.RetrieveWholeTreeByName(File_name_in, Sort_By_column).data;
            [row, col] = find(strcmp(whole_tree, char(File_name_in)));
            %if not on top level
            if row > 1
                File_name_out = whole_tree(row-1,col);
            else
                File_name_out = -1;
            end
        end
        
         function File_name_out = GetImageOneDownInTree(this, File_name_in, Sort_By_column)
             %{
             ---- Retrieve image name of one image down in the tree hierachy.
             The hierachy order column used is defined by Sort_By_column
                           
            ALL NEED TO BE STRINGS, eg
            curs =
              db.GetImageOneDownInTree(char(current_image(14)), 'Hum_C_Score')
            here current_image is the db entry for the image, so the actual
            image can also be used (as 'patch_id112_7364466787.png')
            Returns a filename of the image one level down in the order of 
            Hum_C_Score. 
            If the image is the top leve, -1 gets returned.
                %}
            whole_tree = this.RetrieveWholeTreeByName(File_name_in, Sort_By_column).data;
            [row, col] = find(strcmp(whole_tree, char(File_name_in)));
            [max_r, max_c] = size(whole_tree);
            %if not on bottom level
            if row < max_r+1
                File_name_out = whole_tree(row+1,col);
            else
                File_name_out = -1;
            end
        end
        
        
    end
    
    %---- BELOW ARE THE PRIVATE METHODS----
    methods(Access = private)
        
        function initDB(this, dataBaseName, TableName)
            %{
            ----Initializes specified db/table and connects----
            -ADJUST THE PATH TO YOUR_COMPUTER_JAR_FILE TO MATCH THE LOCATION
            OF YOUR JAR FILE
            -ADJUST THE PATH TO SourceImageFolderPath TO MATCH WHERE YOU
            WANT YOUR DATABASE TO BE STORED
            Args:
            dataBaseName(String) = Name of SQLite database to connect to.
            If doesn't exist, a new will be generated
            tableName(String) = Name of SQLite table to connect to.
            If doesn't exist, a new will be generated
            %}
            YOUR_COMPUTER_JAR_FILE=...
                'C:\Users\Meyer\AppData\Roaming\MathWorks\MATLAB\R2012a\sqlite-jdbc-3.8.11.2.jar';
            this.SourceImageFolderPath = 'C:\sqlite_dbs\';
            javaaddpath(YOUR_COMPUTER_JAR_FILE)
            this.dbName = dataBaseName;
            this.dbTableName = TableName;
            this.dbpath = [this.SourceImageFolderPath,dataBaseName,'.db'];
            this.URL=['jdbc:sqlite:C:\sqlite_dbs\',dataBaseName,'.db'];
            this.Open();
            this.checkIfTableExists();
        end
        
        function checkIfTableExists(this)
            %{
            ----Check if Table exists, if not make new----
            %}
            setdbprefs('DataReturnFormat','numeric');
            qTimeout = 5;
            %make query to get first row of data
            curs = exec(this.Connection,...
                sprintf('select * from %s ORDER BY ROWID ASC LIMIT 1', this.dbTableName),qTimeout);
            ret_data = fetch(curs);
            %if doesn't exist, cursor will return 0, if exist either data
            %or 'No Data'. Use error handling to deal with different data types
            %(string vs int)
            try
                if ret_data.Data == 0
                    %make new table if not present
                    fprintf('adding new table: %s',this.dbTableName);
                    this.addNewTable();
                end
            catch
                fprintf('using existing table: %s',this.dbTableName);
            end
        end
        
        function this = addNewTable(this)
            %{
            ----Init new table with these rows----
            %}
            %CHANGE LINE BELOW TO ADAPT DB ENTRIES (2/3)
            createTable = ['CREATE TABLE ',this.dbTableName,'(Class VARCHAR, '...
                'SubClass VARCHAR, Hum_C_Score VARCHAR, Size VARCHAR, Subset VARCHAR, '...
                'Is_MIRC VARCHAR, Monkey_C_Score VARCHAR, Times_shown VARCHAR, Times_correct VARCHAR, '...
                'Times_wrong VARCHAR, Date_last_shown VARCHAR, Date_added VARCHAR, Is_Original VARCHAR, '...
                'File_name VARCHAR, Unique_branchID VARCHAR, Path VARCHAR)'];
            exec(this.Connection,createTable)
        end
        
    end
    
    
    methods(Static = true)
        function initImageFolder(SourceImageFolderPath)
            %{
            ----Create new image folder if not exist, and count images----
            Args:
            SourceImageFolderPath(String) = Path to folder.
            %}
            img_dir = [SourceImageFolderPath,'SourceImageFolder\'];
            mkdir(img_dir);
            d = dir([img_dir, '\*.png']);
            Folder = dir([img_dir, '\*.set']);
            NumImages=length(d);
            disp(['PNG Images found in source folder: ', num2str(NumImages)])
        end
        
        function unique_ID = generate_unique_ID()
            %{
            ----Create unique ID based on current time as serial----
            %}
            serialDate = floor(now)*10000;
            serialTime = rem(now,1)*10000;
            unique_ID = floor(serialDate+serialTime);
        end
        
        function file_dest = copyOriginal(unique_ID,folder_name, pathstr, SourceImageFolderPath)
            %{
            ----Copy original image from selected folder to ImageFolder----
            Args:
            unique_ID(int) = unique ID to append to filename
            folder_name, SourceImageFolderPath(String) = Path to folders.
            %}
            new_name_original = [folder_name,'_original_',num2str(unique_ID),'.png'];
            file_origin = [pathstr,'\',folder_name,'\original.png'];
            file_dest = [SourceImageFolderPath,'SourceImageFolder\',new_name_original];
            disp(file_dest)
            copyfile(file_origin,file_dest);
        end
        
        function [ImageSavePath, ImageSaveName] = copyImage(currentImage, folder_path, SourceImageFolderPath, unique_ID)
            %{
            ----Copy other images from loop----
            Args:
            currentImage(String) = current image name
            unique_ID(int) = unique ID to append to filename
            folder_name, SourceImageFolderPath(String) = Path to folders.
            %}
            currentImagePath = [folder_path,'\',currentImage];
            ImageSaveName =  [currentImage(1:[end-4]),'_',num2str(unique_ID),'.png'];
            ImageSavePath = [SourceImageFolderPath,'SourceImageFolder\',ImageSaveName];
            copyfile(currentImagePath,ImageSavePath);
            disp(['copied file: ',currentImage]);
        end
        
        function InsertFolder(unique_ID,folder_path, SourceImageFolderPath, Connection,...
                dbTableName,Class_in, SubClass_in, Subset_in, dbcolnames)
            %{
            ----Insert all images of current folder into db----
            Args:
            currentImage(String) = current image name
            unique_ID(int) = unique ID to append to filename
            Connection = db connection object
            dbTableName(string) = name of table to add data to
            SubClass_in(string) = name of Subclass to add data to
            Subset_in(string) = name of Subset to add data to
            dbcolnames(cell) = cell of rows to add data to
            folder_path, SourceImageFolderPath(String) = Path to folders.
                %}
                
                %load csv file to get the meta data from
                [num char raw] = xlsread([folder_path,'\hier_tree_info.csv']);
                Unique_branch_ID = SQLiteImageDataBase.generate_unique_ID();
                %process each image ignoring header
                for i = 2 :  size(raw,1)
                    %copy image into source image folder
                    [ImageSavePath, ImageSaveName]  = SQLiteImageDataBase.copyImage(raw{i,1}, folder_path, SourceImageFolderPath, unique_ID);
                    %grab other info from csv file
                    currentScore = raw{i,2};
                    currentSize = raw{i,3};
                    currentIsMIRC = raw{i,5};
                    %create entry into db as cell
                    dbdata = {Class_in, SubClass_in, currentScore, currentSize, Subset_in, currentIsMIRC, -1,...
                        -1, -1, -1, -1, datestr(now,'yyyy-mm-dd HH:MM:SS'), 0,ImageSaveName,Unique_branch_ID, ImageSavePath};
                    %insert into db using the columnames defined in constructor
                    datainsert(Connection,dbTableName,dbcolnames,dbdata)
                end
        end
        
    end
    
end
