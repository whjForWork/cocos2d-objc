//
//  CCEffectRenderer.m
//  cocos2d-ios
//
//  Created by Thayer J Andrews on 5/21/14.
//
//

#import "CCEffectRenderer.h"
#import "CCConfiguration.h"
#import "CCEffect.h"
#import "CCEffectStack.h"
#import "CCTexture.h"
#import "ccUtils.h"

#import "CCTexture_Private.h"


@interface CCEffectRenderTarget : NSObject

@property (nonatomic, readonly) CCTexture *texture;
@property (nonatomic, readonly) GLuint FBO;
@property (nonatomic, readonly) GLuint depthRenderBuffer;
@property (nonatomic, readonly) BOOL glResourcesAllocated;

@end

@implementation CCEffectRenderTarget

- (id)init
{
    if((self = [super init]))
    {
    }
    return self;
}

- (void)dealloc
{
    if (self.glResourcesAllocated)
    {
        [self destroyGLResources];
    }
}

- (BOOL)allocGLResourcesWithWidth:(int)width height:(int)height
{
    NSAssert(!_glResourcesAllocated, @"");
    
    glPushGroupMarkerEXT(0, "CCEffectRenderTarget: allocateRenderTarget");
    
	// Textures may need to be a power of two
	NSUInteger powW;
	NSUInteger powH;
    
	if( [[CCConfiguration sharedConfiguration] supportsNPOT] )
    {
		powW = width;
		powH = height;
	}
    else
    {
		powW = CCNextPOT(width);
		powH = CCNextPOT(height);
	}
    
    static const CCTexturePixelFormat kRenderTargetDefaultPixelFormat = CCTexturePixelFormat_RGBA8888;
    static const float kRenderTargetDefaultContentScale = 1.0f;
    
    // Create a new texture object for use as the color attachment of the new
    // FBO.
	_texture = [[CCTexture alloc] initWithData:nil pixelFormat:kRenderTargetDefaultPixelFormat pixelsWide:powW pixelsHigh:powH contentSizeInPixels:CGSizeMake(width, height) contentScale:kRenderTargetDefaultContentScale];
	[_texture setAliasTexParameters];
	
    // Save the old FBO binding so it can be restored after we create the new
    // one.
	GLint oldFBO;
	glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldFBO);
    
	// Generate a new FBO and bind it so it can be modified.
	glGenFramebuffers(1, &_FBO);
	glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    
	// Associate texture with FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture.name, 0);
    
	// Check if it worked (probably worth doing :) )
	NSAssert( glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, @"Could not attach texture to framebuffer");
    
    // Restore the old FBO binding.
	glBindFramebuffer(GL_FRAMEBUFFER, oldFBO);
	
	CC_CHECK_GL_ERROR_DEBUG();
	glPopGroupMarkerEXT();
    
    _glResourcesAllocated = YES;
    return YES;
}

- (void)destroyGLResources
{
    NSAssert(_glResourcesAllocated, @"");
    glDeleteFramebuffers(1, &_FBO);
    if (_depthRenderBuffer)
    {
        glDeleteRenderbuffers(1, &_depthRenderBuffer);
    }
    
    _texture = nil;
    
    _glResourcesAllocated = NO;
}

@end


@interface CCEffectRenderer ()

@property (nonatomic, strong) NSMutableArray *renderTargets;
@property (nonatomic, assign) GLKVector4 oldViewport;
@property (nonatomic, assign) GLint oldFBO;

@end


@implementation CCEffectRenderer

-(CCTexture *)outputTexture
{
    CCEffectRenderTarget *rt = [_renderTargets lastObject];
    return rt.texture;
}

-(id)init
{
    return [self initWithWidth:0 height:0];
}

-(id)initWithWidth:(int)width height:(int)height
{
    if((self = [super init]))
    {
        _renderTargets = [[NSMutableArray alloc] init];
        _width = width;
        _height = height;
    }
    return self;
}

-(void)dealloc
{
    [self destroyAllRenderTargets];
}

-(void)drawSprite:(CCSprite *)sprite withEffects:(CCEffectStack *)effectStack renderer:(CCRenderer *)renderer transform:(const GLKMatrix4 *)transform
{
    [self destroyAllRenderTargets];
    
    CCEffectRenderPass* renderPass = [[CCEffectRenderPass alloc] init];
    renderPass.sprite = sprite;
    renderPass.renderer = renderer;
    
    CCTexture *inputTexture = sprite.texture;
    
    CCEffectRenderTarget *previousPassRT = nil;
    for (NSUInteger e = 0; e < effectStack.effectCount; e++)
    {
        CCEffect *effect = [effectStack effectAtIndex:e];
        if(effect.shader && sprite.shader != effect.shader)
        {
            sprite.shader = effect.shader;
            [sprite.shaderUniforms removeAllObjects];
            [sprite.shaderUniforms addEntriesFromDictionary:effect.shaderUniforms];
        }
        
        if (previousPassRT)
        {
            renderPass.sprite.shaderUniforms[@"cc_MainTexture"] = previousPassRT.texture;
        }
        else
        {
            renderPass.sprite.shaderUniforms[@"cc_MainTexture"] = inputTexture;
        }
        
        for(int i = 0; i < effect.renderPassesRequired; i++)
        {
            CCEffectRenderTarget *rt = [self allocRenderTargetWithWidth:_width height:_height];
            
            renderPass.transform = *transform;
            renderPass.renderPassId = i;
            
            if (previousPassRT)
            {
                renderPass.sprite.shaderUniforms[@"cc_PreviousPassTexture"] = previousPassRT.texture;
            }
            else
            {
                renderPass.sprite.shaderUniforms[@"cc_PreviousPassTexture"] = inputTexture;
            }
            
            [effect renderPassBegin:renderPass defaultBlock:nil];

            // Begin
            {
                CGSize pixelSize = rt.texture.contentSizeInPixels;
                GLuint fbo = rt.FBO;
                
                [renderer pushGroup];
                [renderer enqueueBlock:^{
                    glGetFloatv(GL_VIEWPORT, _oldViewport.v);
                    glViewport(0, 0, pixelSize.width, pixelSize.height );
                    
                    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &_oldFBO);
                    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
                    
                } globalSortOrder:NSIntegerMin debugLabel:@"CCEffectRenderer: Bind FBO" threadSafe:NO];
            }
            // /Begin
            
            
            [effect renderPassUpdate:renderPass defaultBlock:^{
                GLKMatrix4 xform = renderPass.transform;
                GLKVector4 clearColor;
                
                renderPass.sprite.anchorPoint = ccp(0.0, 0.0);
                [renderPass.renderer enqueueClear:GL_COLOR_BUFFER_BIT color:clearColor depth:0.0f stencil:0 globalSortOrder:NSIntegerMin];
                [renderPass.sprite visit:renderPass.renderer parentTransform:&xform];
            }];

            
            // End
            {
                [renderer enqueueBlock:^{
                    glBindFramebuffer(GL_FRAMEBUFFER, _oldFBO);
                    glViewport(_oldViewport.v[0], _oldViewport.v[1], _oldViewport.v[2], _oldViewport.v[3]);
                } globalSortOrder:NSIntegerMax debugLabel:@"CCEffectRenderer: Restore FBO" threadSafe:NO];
                
                [renderer popGroupWithDebugLabel:[NSString stringWithFormat:@"CCEffectRenderer: %@: Pass %d", effect.debugName, i] globalSortOrder:0];
            }
            // /End
            
            [effect renderPassEnd:renderPass defaultBlock:nil];
            
            previousPassRT = rt;
        }
    }
}

- (CCEffectRenderTarget *)allocRenderTargetWithWidth:(int)width height:(int)height
{
    CCEffectRenderTarget *rt = [[CCEffectRenderTarget alloc] init];
    [rt allocGLResourcesWithWidth:width height:height];
    [_renderTargets addObject:rt];
    
    return rt;
}

- (void)destroyAllRenderTargets
{
    for (CCEffectRenderTarget *rt in _renderTargets)
    {
        [rt destroyGLResources];
    }
    [_renderTargets removeAllObjects];
}

@end
