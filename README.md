# Matlab Handle Class to connect to an SQLite database for storing images in tree structure with metadata attached to each image. 

The images are copied into a separate folder and only the paths are stored in the database together with the metadata.
The database can be queried for metadata parameter ranges and the image paths get returned.

This current version deals with the storage and organization of differently cropped images which are stored in a tree. A region of a main image (top level of tree) gets cropped to be the second level of the tree. That level gets further croped to form the next level and so on.


**Tree layout (image from Weizman link below):**

![TREE](http://i.imgur.com/4FezCGI.jpg)


The images are used for behavioral studies where the subject has to decide if a subimage is part of a main image (the smaller the subimage, the more difficult it becomes) and the image is analysed for features necessary to identify as belonging to a particular main image. 

Check here for details:
[ Atoms of recognition in human and computer vision (Weizmann)](http://www.wisdom.weizmann.ac.il/~dannyh/Mircs/mircs.html
 "CAMshift") 
 


**See the bottom of this file for setup (you need to download a few things and move them to the right folder, or modify the paths in the matlab file to match where you store the files).**

##### A. Define the image metadata
Each image is shown and attached to it is meta data about how often it was shown, how often correctly identified as being part of the main image, and some basic statistics about how often it should be shown to match the experimental setup. Specific images can be retrieved from the database based on thresholds selected by the user of the class (eg, show images that were correctly identified less than 70%, show images not shown this week, show images only of class *'bicycles'*, etc).

The metatags are defined in the class code and can be changed to fit other needs by changing this line in the **addNewTable()** function as well as the variable **dbcolnames** in the constructor. The current version is:

    createTable = ['CREATE TABLE ',this.dbTableName,'(Class varchar, '...
                 'SubClass NUMERIC, Hum_C_Score NUMERIC, Size NUMERIC, Subset NUMERIC, '...
               'Is_MIRC NUMERIC, Monkey_C_Score NUMERIC, Times_shown NUMERIC, Times_correct NUMERIC, '...
               'Times_wrong NUMERIC, Date_last_shown NUMERIC, Date_added NUMERIC, '...
            'Path VARCHAR)'];


In this case **Class** defines the highest order branch of the tree. It can be eg *'Bike'* to include images of many different bikes, where another **Class** is *'Ships'*, etc.

**Subclass** defines the different *bikes* (eg 1 for a blue bike, 2 for a racing bike, etc) and is one branch of the node **Class** (each image with the same **Subclass** ID should be derived from the same original image).

**Subset** is used to add a tag to each image so you can different sub sets. *BikeBlue* and *BikeBrown* might be assigned **Subset** 1, *BikeRed* and *BikeBlack* might be assigned **Subset** 2, so you can then query for only a portion of the whole data for one week (using **Subset** 1), then have completely different images the next week (using **Subset** 2).

**Hum_C_Score, Monkey_C_Score, Is_MIRC** are all extra Tags that are used to keep statistics of the image properties during the experiment.

*Example Matlab command for db initialization:*

    %Initialize Database and Table
    db = SQLiteImageDataBase('koff', 'Experiment_1');





##### B. Define the folder structure of source Images and Metadata CSV file and add data
Images are added to the database by the **InsertIntoTable(Class_in, SubClass_in, Subset_in)** function, which will ask to select a folder (*ChosenFolder*). The Folder will have one original image and several subfolders (eg *images_id2/*), each subfolder being on tree branch with the images (*.png*) and also a CSV file (*hier_tree_info.csv*) with some of the metadata that will be added to each entry. 

The hierachy is currently set as this:

* ChosenFolder/
  * **original.png**
  * stimuli/
    * images_id2/
      * *hier_tree_info.csv*
      * **patch_id2.png**
      * **patch_id3.png**
      * ...
    * images_id4/
    * ...

As parameters of the **InsertIntoTable(Class_in, SubClass_in, Subset_in)**  function you need to specify where you want the images to be added to (which *Class*, *SubClass* and *Subset*), as there should be the option to extend all those branches later on.

After a folder is selected, the file named **original.png** is copied with a unique ID into the database and added with the *tag Is_Original* set to *True*.
Then the subfolder */stimuli* is chosen and images are read from all folders within the */stimul*i folder (*images_id2, image_id4*, etc).

Each of those folders contains a CSV file with extra info (size of image, C_score, etc) which is processed together with its corresponding image in the private **InsertFolder()** function.

*Example of CSV format:*

| patch_filename  |  score |  size    |  father_id |  mirc_fl |
|-----------------|--------|----------|------------|----------|
| patch_id717.png | 2      | 18       | -1         | 0        |
| patch_id2.png   | 0.58   | 14       | -1         | 1        |
| patch_id12.png  | 0.3    | 11.66667 | 2          | 0        |
| patch_id8.png   | 0.39   | 12       | 2          | 0        |
| patch_id9.png   | 0.15   | 12       | 2          | 0        |




####

*Matlab command for image insertion:*

    %Add images and Metadata to Table
    db.InsertIntoTable('Bike_blue', 1, 2);


**Here an example of the data within the database (using SQL browser)**
![sql](http://i.imgur.com/HEgIQfm.jpg)




##### C. Query the db table for different range of parameters
Use the **RetrieveEntriesFromTable()** function to retrieve db entries within a defined range across defined columns.

In the current version the db columns used are 
* **Class** (*specify what class it belongs to, eg 'Bike'*), 
* range of **Subclass** (between eg 1 and 4), 
* range of **C_scores** (between eg 0.5 and 0.7) and 
* range of **times_shown** (between eg 100 and 200).

As there might be many entries you can limit the number of entries returned (**max_entries**) and what column to use for that limit (eg show only the top 100 **times_shown**).

**All parameters need to be strings, and the cursor object gets returned, which can be extended by using .data.**

*Matlab command for db query:*

    %Query table for parameter ranges
    db.RetrieveEntriesFromTable('Bike_blue', '0','1', '0.5','0.7' , '0', '2', '0', '-1', '0', '-1','0', 'Hum_C_Score', '50','0'  )
    %expand the cursor to get data
    the_data = ans.data



**Here the returned data from above query**
![TREE](http://i.imgur.com/omc37rg.jpg)



The image can then be loaded using:

    %get path entry for first image from query
    imagePath = the_data(1,14);
    %convert cell to string
    imagePath_string = sprintf('%s\n',the_data{:})
    %load image into Matlab
    imread(imagePath_string)



##### D. Complete API
#


##### 1. Connect to database named 'Koff' with a SQLite table called 'Experiment_1'. If neither exists, it will be created. Will also index the specified folder that contains all source images.
#
    db = SQLiteImageDataBase('koff', 'Experiment_1');
    
*Connection open.*

*Location: C:\sqlite_dbs\koff.db*

*PNG Images found in source folder: 2089*

##### 2. Add images and Metadata to Table with a new name 'Bike_blue' and the Subclass of '1' and into the Subset of '2'. You will be asked to specify the source folder of the images.
#
    db.InsertIntoTable('Bike_blue', 1, 2);

##### 3. Query table for parameter ranges of image metadata. Eg. Get all entries of this range sorted by Hum_C_score .
#
    query_return = db.RetrieveEntriesFromTable('Bike_blue2', '0','1',...
    '0.5','0.7' , '0', '2', '0', '-1', '0', '-1','0', 'Hum_C_Score', '50','0')


Expand the cursor to get data into the Matlab workspace as cell matrix

    the_data = ans.query_return


##### 4. Get one image metadata using the file name of image as query
#
    current_image_data =
    db.RetrieveSingleEntryByName('patch_id107_7364456323.png').data
    

##### 5. Update Entry by filename as query. Eg.update data in column 'Times_wrong' to '1002'.
#
    db.UpdateEntry(char(current_image_data(14)),'Times_wrong',1002)

Row 14 is the image name within the image data (can also use **'patch_id107_7364456323.png'** instead of **current_image_data(14)**)

 
##### 6. Retrieve the whole image tree the current image belongs to.
#
    current_tree = 
        db.RetrieveWholeTreeByName(char(current_image_data(14)).data,
        'Hum_C_Score')

The tree is based on what was specified in the initial image import as being part of the same tree. Specify with second parameter what you want your tree to be ordered as.

##### 7. Retrieve the image name one level up in tree, using eg 'Hum_C_Score' as tree order.
#
    current_tree = 
        db.RetrieveWholeTreeByName(char(current_image_data(14)).data,
        'Hum_C_Score')


##### 8. Retrieve the image name one level down in tree, using eg 'Hum_C_Score' as tree order.
#
    current_tree = 
        db.GetImageOneDownInTree(char(current_image_data(14)).data,
        'Hum_C_Score')
        


 ##### FOLLOW BELOW AS INITIAL SETUP
 
1. download SQLite3 (I used Sqlite 3.11)
    https://www.sqlite.org/download.html
    
2. download driver sqlite-jdbc-3.8.11.2.jar from

    https://bitbucket.org/xerial/sqlite-jdbc/downloads
    
    and change the path below at varible YOUR_COMPUTER_JAR_FILE to match
    the location where you saved it
    eg 'C:\Users\Meyer\AppData\Roaming\MathWorks\MATLAB\R2012a\sqlite-jdbc-3.8.11.2.jar'
    
3. make a folder in 'C:' called 'sqlite_dbs' where your databases are
    stored
    ('eg C:\sqlite_dbs\')
    
4. to view the data outside of Matlab, download SQLite browser from
    http://sqlitebrowser.org/
    

for more help:

http://www.mathworks.com/help/database/ug/sqlite-jdbc-windows.html
    
    EXAMPLE USE:
    %Initialize Database and Table
    db = SQLiteImageDataBase('koff', 'Experiment_1');
    
    %Add images and Metadata to Table
    db.InsertIntoTable('Bike_blue', 1, 2);
    
    %Query table for parameter ranges
     range = db.RetrieveEntriesFromTable('Bike_blue2', '0','1', '0.5','0.7' , '0', '2', '0', '-1', '0', '-1','0', 'Hum_C_Score', '50','0')
 
    %expand the cursor to get data into the Matlab workspace as cell matrix
    the_data = range.data
    
    %update entry 'Times_wrong' for current_image to 1000   
     db.UpdateEntry(char(current_image(14)),'Times_wrong',1000)
     
    %retrieve the data for a single image using the image name
    image_data = db.RetrieveSingleEntryByName('char(current_image(14))).data
    
    %retrieve the complete tree where the current_image belongs to, ordered by Hum_C_Score
    current_tree =
    db.RetrieveWholeTreeByName(char(current_image(15)).data, 'Hum_C_Score')
      
    %retrieve file name of the next image up one level in tree based on the tree hierachy of Hum_C_Score'
    im_name = db.GetImageOneUpInTree(char(ans), 'Hum_C_Score')
    
     %retrieve file name of the next image up one level in tree based on the tree hierachy of Hum_C_Score'
    im_name = db.GetImageOneDownInTree(char(ans), 'Hum_C_Score')
  
    








emails to:
 <fuschro@gmail.com>