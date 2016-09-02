//
//  FileListViewController.m
//  AnyScreen
//
//  Created by pcbeta on 16/5/13.
//  Copyright © 2016年 xindawn. All rights reserved.
//

#import "FileListViewController.h"
#import "IDFileManager.h"
#import "AVPlayerViewController.h"
#import "FileListTableViewCell.h"
#import "CSScreenRecorder.h"
#import "H264ViewController.h"

@interface FileListViewController ()<UITableViewDataSource, UITableViewDelegate>

{
    NSMutableArray *_folderItems;
    NSMutableArray *_inHandleItems;
    
    int selectedRow;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectAllBtn;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editBtn;

@end

@implementation FileListViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

    _inHandleItems = [[NSMutableArray alloc] init];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
}

- (void)reloadFileList
{
    _folderItems = nil;
    _folderItems = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[IDFileManager inDocumentsDirectory:@""] error:nil] mutableCopy];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self reloadFileList];
    
    [self.tableView reloadData];
    
     self.tableView.editing = NO;
    self.toolBar.hidden = !self.tableView.editing;

//    NSLog(@"kdd: view did appear .... 111");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fielAdded:) name:kFileAddedNotification object:nil];

}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)fielAdded:(NSNotification *)notification
{
    NSLog(@"kdd, fielAdded........");
    [self reloadFileList];
    [self.tableView reloadData];
}


- (void)dealloc {
    _folderItems = nil;
    _inHandleItems = nil;
    NSLog(@"kdd: dealloc for FileListViewController");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
//#warning Incomplete implementation, return the number of sections
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//#warning Incomplete implementation, return the number of rows
    NSInteger c = [_folderItems count];
    
    if(c == 0)
    {
        [self.editBtn setEnabled:NO];
//        self.tableView.editing = NO;
        self.toolBar.hidden = YES;
    }
    else
    {
        [self.editBtn setEnabled:YES];
    }
   
    return c;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *CellIdentifier = @"reuseIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    cell.textLabel.text = [_folderItems objectAtIndex:indexPath.row];
 //   cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
   
    NSString *fileName = [_folderItems objectAtIndex:indexPath.row];
    NSString *filePath = [IDFileManager inDocumentsDirectory:fileName];
    NSLog(@"FNAME:%@", fileName);
    unsigned long long size = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
    cell.detailTextLabel.text = [IDFileManager humanReadableStringFromBytes:size];
   
    
    return cell;
}



// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"\n\nkdd:commitEditingStyle\n\n");
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(self.tableView.isEditing)
    {
        [_inHandleItems addObject:[_folderItems objectAtIndex:indexPath.row]];
    }
    else
    {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        selectedRow = indexPath.row;
    
        [self delayMethod:selectedRow];
    }
    
    H264ViewController *destViewController = [[H264ViewController alloc] init];
    //
    NSString *fileName = [_folderItems objectAtIndex:selectedRow];
    NSString *filePath = [IDFileManager inDocumentsDirectory:fileName];
    
    //destViewController.stringName = filePath;
    destViewController.fileName = filePath;
    
    [self.navigationController pushViewController:destViewController animated:YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath  {
    
    if(self.tableView.isEditing)
    {
        [_inHandleItems removeObject:[_folderItems objectAtIndex:indexPath.row]];
   }
    
}

- (void)delayMethod:(int)index
{
     //[self performSegueWithIdentifier:@"goVideo" sender:self];
}


// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if([segue.identifier isEqualToString:@"goVideo"]){
//        AVPlayerViewController *destViewController = segue.destinationViewController;
//        
//        NSString *fileName = [_folderItems objectAtIndex:selectedRow];
//        NSString *filePath = [IDFileManager inDocumentsDirectory:fileName];
//
//        destViewController.stringName = filePath;
//        destViewController.movieName = fileName;
        
        H264ViewController *destViewController = segue.destinationViewController;
        //
        NSString *fileName = [_folderItems objectAtIndex:selectedRow];
        NSString *filePath = [IDFileManager inDocumentsDirectory:fileName];

        //destViewController.stringName = filePath;
        destViewController.fileName = fileName;
        
    }
}

- (IBAction)onEditButton:(id)sender
{
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    
    self.tableView.editing = !self.tableView.editing;
    
    [_inHandleItems removeAllObjects];
    
     self.toolBar.hidden = !self.tableView.editing;
}

- (IBAction)onSelectAllButton:(id)sender
{
    for (int i = 0; i < [self.tableView numberOfRowsInSection:0]; i ++)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
        
        [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionTop];
        
        [_inHandleItems addObject:[_folderItems objectAtIndex:indexPath.row]];
    }
}

- (IBAction)onDeleteButton:(id)sender
{
    if(self.tableView.isEditing)
    {
        for (NSString * theStr in _inHandleItems) {
            NSLog(@"%@:",theStr);
            NSString *filePath = [IDFileManager inDocumentsDirectory:theStr];
            NSURL* url = [NSURL fileURLWithPath:filePath];
            [IDFileManager removeFile:url];
        }
        
        [_inHandleItems removeAllObjects];
        
        [self reloadFileList];
        [self.tableView reloadData];
    }
}


- (IBAction)onCopyButton:(id)sender
{
    if(self.tableView.isEditing)
    {
        for (NSString * theStr in _inHandleItems) {
            NSLog(@"%@:",theStr);
            NSString *filePath = [IDFileManager inDocumentsDirectory:theStr];
            NSURL* url = [NSURL fileURLWithPath:filePath];

            [IDFileManager copyFileToCameraRoll:url didFinishcompledBlock:nil];
        }
        
    }

}
@end
