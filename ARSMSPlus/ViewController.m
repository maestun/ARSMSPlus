//
//  ViewController.m
//  artest2
//
//  Created by geo on 04/10/2017.
//  Copyright © 2017 picmeapp. All rights reserved.
//

#import "ViewController.h"
#import "shared.h"
#import <sys/time.h>

@interface ViewController () <ARSCNViewDelegate> {
    SCNGeometry * mBox;
}

@property (nonatomic, strong) IBOutlet ARSCNView *sceneView;
@property (weak, nonatomic) IBOutlet UIButton *btn1;
@property (weak, nonatomic) IBOutlet UIButton *btn2;
@property (weak, nonatomic) IBOutlet UIButton *btnUp;
@property (weak, nonatomic) IBOutlet UIButton *btnDown;
@property (weak, nonatomic) IBOutlet UIButton *btnLeft;
@property (weak, nonatomic) IBOutlet UIButton *btnRight;

@end

    
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

//    // Set the view's delegate
//    self.sceneView.delegate = self;
//
//    // Show statistics such as fps and timing information
//    self.sceneView.showsStatistics = YES;
//
//    // Create a new scene
//    SCNScene *scene = [SCNScene sceneNamed:@"art.scnassets/ship.scn"];
//
//    // Set the scene to the view
//    self.sceneView.scene = scene;
    // Container to hold all of the 3D geometry
    SCNScene *scene = [SCNScene new];
    // The 3D cube geometry we want to draw
    mBox = [SCNBox
                           boxWithWidth:0.25
                           height:0.25
                           length:0.25
                           chamferRadius:0];
    
    // The node that wraps the geometry so we can add it to the scene
    SCNNode *boxNode = [SCNNode nodeWithGeometry:mBox];
    // Position the box just in front of the camera
    boxNode.position = SCNVector3Make(0, 0, -0.5);
    // rootNode is a special node, it is the starting point of all
    // the items in the 3D scene
    [scene.rootNode addChildNode: boxNode];
    
    self.sceneView.autoenablesDefaultLighting = YES;

    // Set the scene to the view
    self.sceneView.scene = scene;

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Create a session configuration
    ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];

    // Run the view's session
    [self.sceneView.session runWithConfiguration:configuration];
    
    
    [self SMS_StartEmulation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Pause the view's session
    [self.sceneView.session pause];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - ARSCNViewDelegate

/*
// Override to create and configure nodes for anchors added to the view's session.
- (SCNNode *)renderer:(id<SCNSceneRenderer>)renderer nodeForAnchor:(ARAnchor *)anchor {
    SCNNode *node = [SCNNode new];
 
    // Add geometry to the node...
 
    return node;
}
*/

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    // Present an error message to the user
    
}

- (void)sessionWasInterrupted:(ARSession *)session {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay
    
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    // Reset tracking and/or remove existing anchors if consistent tracking is required
    
}


// ===========================================================================================
#pragma mark - SMSPlus
// ===========================================================================================
volatile int frame_skip      = 1;
volatile int frame_count     = 0;
volatile int frames_rendered = 0;
volatile int frame_rate      = 0;
volatile int64_t tick_count      = 0;
volatile int old_tick_count  = 0;
static BOOL sRunning = NO;

- (void)SMS_StartEmulation {
    
    NSString * path = [[NSBundle mainBundle] bundlePath];
    path = [path stringByAppendingPathComponent:@"ken.sms"];
    
    strcpy(game_name, [path cStringUsingEncoding:NSUTF8StringEncoding]);
//    NSString * path = [NSString stringWithFormat:@"%@%s", NSTemporaryDirectory(), game_name];
//    [[self romData] writeToFile:path atomically:NO];
    
    int ret = load_rom((char *)[path cStringUsingEncoding:NSUTF8StringEncoding]);
    if(ret) {
        sRunning = YES;
        [[[NSThread alloc] initWithTarget:self selector:@selector(SMS_Run) object:nil] start];
    }
    else {
        NSLog(@"load rom failed");
    }
    
}

- (void)SMS_StopEmulation {
    sRunning = false;
}

/* Save or load SRAM */
void system_manage_sram(uint8 *sram, int slot, int mode)
{
    char name[PATH_MAX];
    FILE *fd;
    strcpy(name, game_name);
    strcpy(strrchr(name, '.'), ".sav");
    
    switch(mode)
    {
        case SRAM_SAVE:
            if(sms.save)
            {
                fd = fopen(name, "wb");
                if(fd)
                {
                    fwrite(sram, 0x8000, 1, fd);
                    fclose(fd);
                }
            }
            break;
            
        case SRAM_LOAD:
            fd = fopen(name, "rb");
            if(fd)
            {
                sms.save = 1;
                fread(sram, 0x8000, 1, fd);
                fclose(fd);
            }
            else
            {
                /* No SRAM file, so initialize memory */
                memset(sram, 0x00, 0x8000);
            }
            break;
    }
}

#define BUFFER_WIDTH        (256)
#define BUFFER_HEIGHT       (192)
#define NUM_COMPONENTS      (4)
#define BITS_PER_COMPONENT  (8)

- (void)SMS_Run {
    
    /* Set up bitmap structure */
    memset(&bitmap, 0, sizeof(bitmap_t));
    bitmap.width  = BUFFER_WIDTH;
    bitmap.height = BUFFER_HEIGHT;
    bitmap.depth  = BITS_PER_COMPONENT; // color depth. Must be 8 or 16
    bitmap.pitch  = bitmap.width;// * (bitmap.depth / 8); // width of the bitmap, in *bytes*

    bitmap.data   = (uint8_t *)malloc(bitmap.width * bitmap.height);
    //    bitmap.viewport.x = 0;
    //    bitmap.viewport.y = 0;
    bitmap.viewport.w = BUFFER_WIDTH;
    bitmap.viewport.h = BUFFER_HEIGHT;
    
    system_init();
    system_poweron();
    
    /* Main emulation loop */
    CADisplayLink * dl = [CADisplayLink displayLinkWithTarget:self selector:@selector(render_frame)];
    [dl addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    // TODO: remove from run loop
    
}

- (void)render_frame {
    frame_count++;
    frames_rendered++;
    system_frame(0);
    UIImage * texture = [self imageFromTexturePixels];
    
    // material
    SCNMaterial * mat = [SCNMaterial material];
    [mat setLightingModelName:SCNLightingModelConstant];
    [[mat diffuse] setContents:texture];
    [mat setDoubleSided:YES];
    [mBox setFirstMaterial:mat];
//    return mat;
}


static uint8_t * sPixelsARGB = nil;

- (UIImage *)imageFromTexturePixels {
    if(sPixelsARGB == nil) {
        sPixelsARGB = malloc(bitmap.width * bitmap.height * NUM_COMPONENTS);
    }
    /* Pack RGB data into a 16-bit RGB 5:6:5 format */
    uint32_t dst_index = 0;
    for(int y = 0; y < bitmap.height; y++) {
        for(int x = 0; x < bitmap.width; x++) {
            
            uint32_t src_index = x + (y * bitmap.width);
            
            uint8_t pal_index = (uint8_t)bitmap.data[src_index];
            uint8_t r = bitmap.pal.color[pal_index][0];
            uint8_t g = bitmap.pal.color[pal_index][1];
            uint8_t b = bitmap.pal.color[pal_index][2];
            
            // ignored sPixelsARGB[dst_index + 0] = 0xff;
            sPixelsARGB[dst_index + 1] = r;
            sPixelsARGB[dst_index + 2] = g;
            sPixelsARGB[dst_index + 3] = b;
            
            dst_index += 4;
        }
    }
    
    
    CGColorSpaceRef csp = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(sPixelsARGB,
                                                 (size_t)bitmap.width, (size_t)bitmap.height,
                                                 BITS_PER_COMPONENT,
                                                 NUM_COMPONENTS * (size_t)bitmap.width,
                                                 csp,
                                                 kCGImageAlphaNoneSkipFirst);

    CGColorSpaceRelease(csp);
    CGImageRef img = CGBitmapContextCreateImage(context);
    UIImage * newImage = [[UIImage alloc] initWithCGImage:img scale:1 orientation:UIImageOrientationUp];
    CFRelease(img);
    CFRelease(context);
    return newImage;
}




- (IBAction)one_down:(id)sender {
    input.pad[0] |= INPUT_BUTTON2;
}
- (IBAction)one_up_inside:(id)sender {
    input.pad[0] ^= INPUT_BUTTON2;
}
- (IBAction)one_up_outside:(id)sender {
    [self one_up_inside:sender];
}


- (IBAction)two_down:(id)sender {
    input.pad[0] |= INPUT_BUTTON1;
}
- (IBAction)two_up_inside:(id)sender {
    input.pad[0] ^= INPUT_BUTTON1;
}
- (IBAction)two_up_outside:(id)sender {
    [self two_up_inside:sender];
}


- (IBAction)up_down:(id)sender {
    input.pad[0] |= INPUT_UP;
}
- (IBAction)up_up_inside:(id)sender {
    input.pad[0] ^= INPUT_UP;
}
- (IBAction)up_up_outside:(id)sender {
    [self up_up_inside:sender];
}


- (IBAction)down_down:(id)sender {
    input.pad[0] |= INPUT_DOWN;
}
- (IBAction)down_up_inside:(id)sender {
    input.pad[0] ^= INPUT_DOWN;
}
- (IBAction)down_up_outside:(id)sender {
    [self down_up_inside:sender];
}


- (IBAction)left_down:(id)sender {
    input.pad[0] |= INPUT_LEFT;
}
- (IBAction)left_up_inside:(id)sender {
    input.pad[0] ^= INPUT_LEFT;
}


- (IBAction)right_down:(id)sender {
    input.pad[0] |= INPUT_RIGHT;
}
- (IBAction)right_up_inside:(id)sender {
    input.pad[0] ^= INPUT_RIGHT;
}


- (IBAction)pause_down:(id)sender {
    input.pad[0] |= INPUT_RESET;
}
- (IBAction)pause_up_inside:(id)sender {
    input.pad[0] ^= INPUT_RESET;
}
- (IBAction)pause_up_outside:(id)sender {
    [self pause_up_inside:sender];
}


@end
