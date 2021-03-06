/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2013 Apportable Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "CCNode.h"

/**
 The possible states for a CCControl.
 */
typedef NS_ENUM(NSUInteger, CCControlState)
{
    /** The normal, or default state of a control — that is, enabled but neither selected nor highlighted. */
    CCControlStateNormal       = 1 << 0,
    
    /** Highlighted state of a control. A control enters this state when a touch down, drag inside or drag enter is performed. 
     You can retrieve and set this value through the highlighted property. */
    CCControlStateHighlighted  = 1 << 1,
    
    /** Disabled state of a control. This state indicates that the control is currently disabled. 
     You can retrieve and set this value through the enabled property. */
    CCControlStateDisabled     = 1 << 2,
    
    /** Selected state of a control. This state indicates that the control is currently selected. 
     You can retrieve and set this value through the selected property. */
    CCControlStateSelected     = 1 << 3
};


/**
 CCControl is the abstract base class of the Cocos2D GUI components. 
 It handles touch/mouse events. Its subclasses use child nodes to draw themselves in the node hierarchy.
 
 You should not instantiate CCControl directly. Instead use one of its sub-classes:
 
 - CCButton
 - CCSlider
 - CCTextField
 
 If you need to create a new GUI control you should make it a subclass of CCControl.
 
 @note If you are subclassing CCControl you should `#import "CCControlSubclass.h"` in your subclass as it includes methods that are not publicly exposed.
 */
@interface CCControl : CCNode
{
    /** Needs layout is set to true if the control has changed and needs to re-layout itself. */
    BOOL _needsLayout;
}


/// -----------------------------------------------------------------------
/// @name Controlling Content Size
/// -----------------------------------------------------------------------

/** The preferred (and minimum) size that the component will attempt to layout to. If its contents are larger it may have a larger size. */
@property (nonatomic,assign) CGSize preferredSize;

/** The content size type that the preferredSize is using. Please refer to the CCNode documentation on how to use content size types.
 @see CCSizeType, CCSizeUnit */
@property (nonatomic,assign) CCSizeType preferredSizeType;

/** The maximum size that the component will layout to, the component will not be larger than this size and will instead shrink its content if needed. */
@property (nonatomic,assign) CGSize maxSize;

/** The content size type that the preferredSize is using. Please refer to the CCNode documentation on how to use content size types.
 @see CCSizeType, CCSizeUnit */
@property (nonatomic,assign) CCSizeType maxSizeType;


/// -----------------------------------------------------------------------
/// @name Setting and Getting Control Attributes
/// -----------------------------------------------------------------------

/** Sets or retrieves the current state of the control.
 @note This property is a bitmask. It's easier to use the enabled, highlighted and selected properties to indirectly set or read this property.
 @see CCControlState
 @see enabled, selected, highlighted */
@property (nonatomic,assign) CCControlState state;

/** Determines if the control is currently enabled. */
@property (nonatomic,assign) BOOL enabled;

/** Determines if the control is currently selected. E.g. this is used by toggle buttons to handle the on state. */
@property (nonatomic,assign) BOOL selected;

/** Determines if the control is currently highlighted. E.g. this corresponds to the down state of a button */
@property (nonatomic,assign) BOOL highlighted;

/** True if the control continously should generate events when it's value is changed. E.g. this can be used by slider controls
 to run the block/selector whenever the slider is moved. */
@property (nonatomic,assign) BOOL continuous;

/// -----------------------------------------------------------------------
/// @name Accessing Control State
/// -----------------------------------------------------------------------

/** True if the control is currently tracking touches or mouse events. That is, if the user has touched down in the component
 but not lifted his finger (the actual touch may be outside the component). */
@property (nonatomic,readonly) BOOL tracking;

/** True if the control currently has a touch or a mouse event within its bounds. */
@property (nonatomic,readonly) BOOL touchInside;


/// -----------------------------------------------------------------------
/// @name Receiving Action Callbacks
/// -----------------------------------------------------------------------

/** A block that handles action callbacks sent by the control. The block runs when the control subclass is activated (ie slider moved, button tapped).
 
 The block must have the following signature: `void (^)(id sender)` where sender is the sending CCControl subclass. For example:
 
    control.block = ^(id sender) {
        NSLog(@"control activated by: %@", sender);
    };
 
 @see setTarget:selector:
 */
@property (nonatomic,copy) void(^block)(id sender);

/**
 Sets a target and selector that should be called when an action is triggered by the control. Actions are generated when buttons are clicked, sliders are dragged etc.
 
 The selector must have the following signature: `-(void) theSelector:(id)sender` where sender is the sending CCControl subclass.
 It is therefore legal to implement the selector more specifically as, for instance:
 
    -(void) onSliderDragged:(CCSlider*)slider
    {
        NSLog(@"sender: %@", slider);
    }
 
 Provided that this selector was assigned to a CCSlider instance.
 
 @param target   The target object to which the message should be sent.
 @param selector Selector in target object receiving the message.
 @see block
 */
-(void) setTarget:(id)target selector:(SEL)selector;

@end
