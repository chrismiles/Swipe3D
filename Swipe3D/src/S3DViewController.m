//
//  S3DViewController.m
//  Swipe3D
//
//  Created by Chris Miles on 8/08/12.
//  Copyright (c) 2012 Chris Miles. All rights reserved.
//
//  MIT Licensed (http://opensource.org/licenses/mit-license.php):
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "S3DViewController.h"
#import "Swipe_Vertical.h"


@interface S3DViewController () {
    BOOL _colourModeReflective;
    BOOL _isUserRotating;
    float _rotation;
    float _wobble;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    GLuint _indexBuffer;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKTextureInfo *skyboxCubemap;

@property (strong, nonatomic) GLKBaseEffect *effect;
@property (strong, nonatomic) GLKReflectionMapEffect *reflectionMapEffect;
@property (strong, nonatomic) GLKSkyboxEffect *skyboxEffect;

@property (weak, nonatomic) IBOutlet UIToolbar *bottomToolbar;

- (void)setupGL;
- (void)tearDownGL;

@end

@implementation S3DViewController
@synthesize bottomToolbar = _bottomToolbar;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    self.preferredFramesPerSecond = 60;
    
    [self setupGL];
    
    self.bottomToolbar.items = [self makeToolbarItems];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rotatePanGestureRecognizer:)];
    [self.view addGestureRecognizer:panGestureRecognizer];
}

- (void)viewDidUnload
{    
    [self setBottomToolbar:nil];
    [super viewDidUnload];
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
	self.context = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc. that aren't in use.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (NSArray *)makeToolbarItems
{
    UIBarButtonItem *flexItem1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    UISegmentedControl *fillModeControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Coloured", @"Reflective", nil]];
    fillModeControl.segmentedControlStyle = UISegmentedControlStyleBar;
    fillModeControl.selectedSegmentIndex = 0;
    [fillModeControl addTarget:self action:@selector(colourModeControlAction:) forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *fillModeItem = [[UIBarButtonItem alloc] initWithCustomView:fillModeControl];
    
    UIBarButtonItem *flexItem2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    return [NSArray arrayWithObjects:flexItem1, fillModeItem, flexItem2, nil];
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    self.effect = [[GLKBaseEffect alloc] init];
    self.effect.light0.enabled = GL_TRUE;
    self.effect.light0.diffuseColor = GLKVector4Make(245.0f/255.0f, 130.0f/255.0f, 32.0f/255.0f, 1.0f);
    
    self.reflectionMapEffect = [[GLKReflectionMapEffect alloc] init];
    self.reflectionMapEffect.light0.enabled = GL_TRUE;
    
    self.reflectionMapEffect.material.diffuseColor = GLKVector4Make(245.0f/255.0f, 130.0f/255.0f, 32.0f/255.0f, 1.0f);
    self.reflectionMapEffect.material.ambientColor = GLKVector4Make(0.5f, 0.5f, 0.5f, 1.0f);
    self.reflectionMapEffect.material.emissiveColor = GLKVector4Make(0.2f, 0.2f, 0.2f, 1.0f);

    NSArray *skyboxCubeMapFilenames = @[
	[[NSBundle mainBundle] pathForResource:@"skybox_cubemap_right" ofType:@"jpg"],
	[[NSBundle mainBundle] pathForResource:@"skybox_cubemap_left" ofType:@"jpg"],
	[[NSBundle mainBundle] pathForResource:@"skybox_cubemap_up" ofType:@"jpg"],
	[[NSBundle mainBundle] pathForResource:@"skybox_cubemap_down" ofType:@"jpg"],
	[[NSBundle mainBundle] pathForResource:@"skybox_cubemap_front" ofType:@"jpg"],
	[[NSBundle mainBundle] pathForResource:@"skybox_cubemap_back" ofType:@"jpg"],
    ];
    NSError *error = nil;
    NSDictionary *options = @{ GLKTextureLoaderOriginBottomLeft: [NSNumber numberWithBool:NO] };
    self.skyboxCubemap = [GLKTextureLoader cubeMapWithContentsOfFiles:skyboxCubeMapFilenames options:options error:&error];

    self.skyboxEffect = [[GLKSkyboxEffect alloc] init];
    self.skyboxEffect.label = @"Main Sky Box Effect";
    self.skyboxEffect.textureCubeMap.name = self.skyboxCubemap.name;
    
    self.reflectionMapEffect.textureCubeMap.name = self.skyboxCubemap.name;
    
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, Swipe_Vertical_IVAlength*sizeof(GL_FLOAT), Swipe_Vertical_IVA, GL_STATIC_DRAW);
    
    GLsizei stride = 8*sizeof(GLfloat);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, stride, (char *)(0));
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, stride, (char *)(3*sizeof(GLfloat)));
    
    // Note: we don't use the texture coords in this demo; ideally they would be stripped out of the vertex data.
    
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, Swipe_Vertical_NumIndices*sizeof(GLushort), Swipe_Vertical_Indices, GL_STATIC_DRAW);

    glBindVertexArrayOES(0);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    self.effect = nil;
    self.reflectionMapEffect = nil;
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    self.effect.transform.projectionMatrix = projectionMatrix;
    self.reflectionMapEffect.transform.projectionMatrix = projectionMatrix;
    self.skyboxEffect.transform.projectionMatrix = projectionMatrix;
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 0.0f, 1.0f, 0.0f);
    
    self.reflectionMapEffect.matrix = GLKMatrix3InvertAndTranspose(GLKMatrix3MakeRotation(-_rotation, 0.0f, 1.0f, 0.0f), NULL);

    CGFloat skyboxScale = 50.0f;
    GLKMatrix4 skyboxMatrix = GLKMatrix4Scale(modelViewMatrix, skyboxScale, skyboxScale, skyboxScale);
    self.skyboxEffect.transform.modelviewMatrix = skyboxMatrix;

    // wobble
    modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 0.0f, -0.5f, 0.0f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, GLKMathDegreesToRadians(sinf(_wobble)*35.0f), 0.0f, 0.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 0.0f, 0.5f, 0.0f);
    self.effect.transform.modelviewMatrix = modelViewMatrix;
    self.reflectionMapEffect.transform.modelviewMatrix = modelViewMatrix;
    
    if (! _isUserRotating) {
	_rotation += self.timeSinceLastUpdate * 0.25f;
    }
    _wobble += self.timeSinceLastUpdate;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self.skyboxEffect prepareToDraw];
    [self.skyboxEffect draw];
    
    glBindVertexArrayOES(_vertexArray);
    
    if (_colourModeReflective) {
	[self.reflectionMapEffect prepareToDraw];
    }
    else {
	[self.effect prepareToDraw];
    }
    
    glDrawElements(GL_TRIANGLES, Swipe_Vertical_NumIndices, GL_UNSIGNED_SHORT, NULL);
}


#pragma mark - Change colour mode

- (void)colourModeControlAction:(id)sender
{
    _colourModeReflective = [(UISegmentedControl *)sender selectedSegmentIndex];
}


#pragma mark - Rotation by pan gesture

static const CGFloat kPanRotationFactor = 0.02f;

- (void)rotatePanGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer
{
    static CGPoint panPrevious;
    
    if (panGestureRecognizer.state == UIGestureRecognizerStateBegan) {
	_isUserRotating = YES;
	panPrevious = [panGestureRecognizer locationInView:self.view];
    }
    else {
	CGPoint panLocation = [panGestureRecognizer locationInView:self.view];
	CGPoint panDelta = CGPointMake(panLocation.x-panPrevious.x, panLocation.y-panPrevious.y);
	
	_rotation += panDelta.x * kPanRotationFactor;
	
	panPrevious = panLocation;
	
	if (panGestureRecognizer.state == UIGestureRecognizerStateEnded || panGestureRecognizer.state == UIGestureRecognizerStateCancelled) {
	    _isUserRotating = NO;
	}
    }
}

@end
