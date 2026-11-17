#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <math.h>

#define WIDTH 1080
#define HEIGHT 1920
#define FPS 30
#define TOTAL_FRAMES 900 // 30 seconds

// Easing & math helpers
static inline double clamp(double v, double minVal, double maxVal) {
    return (v < minVal) ? minVal : ((v > maxVal) ? maxVal : v);
}

static inline double lerp(double a, double b, double t) {
    return a + (b - a) * t;
}

static inline double easeOutCubic(double t) {
    t = clamp(t, 0.0, 1.0) - 1.0;
    return t * t * t + 1.0;
}

static inline double easeInOutQuad(double t) {
    t = clamp(t, 0.0, 1.0);
    return t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0;
}

// Pseudo random
static inline double pseudoRand(int seed) {
    long s = (seed * 1103515245L + 12345L) & 0x7fffffffL;
    return (double)s / 2147483647.0;
}

// Text drawing helper with stroke outline + glow
static void drawStyledText(CGContextRef ctx, NSString *text, NSString *fontName, CGFloat fontSize,
                           CGPoint center, CGColorRef fillColor, CGColorRef strokeColor, CGFloat strokeWidth,
                           BOOL hasBox, CGColorRef boxColor) {
    CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)fontName, fontSize, NULL);
    if (!font) font = CTFontCreateWithName(CFSTR("HelveticaNeue-Bold"), fontSize, NULL);
    
    NSDictionary *attrs = @{
        (id)kCTFontAttributeName: (__bridge id)font,
        (id)kCTForegroundColorAttributeName: (__bridge id)fillColor
    };
    CFAttributedStringRef attrStr = CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef)text, (__bridge CFDictionaryRef)attrs);
    CTLineRef line = CTLineCreateWithAttributedString(attrStr);
    
    CGFloat ascent, descent, leading;
    double lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CGFloat lineTotalHeight = ascent + descent;
    
    CGFloat originX = center.x - lineWidth / 2.0;
    CGFloat originY = center.y - lineTotalHeight / 2.0 + descent;
    
    // Draw background box/pill if requested
    if (hasBox && boxColor) {
        CGContextSaveGState(ctx);
        CGFloat padX = 24.0, padY = 14.0;
        CGRect boxRect = CGRectMake(originX - padX, center.y - lineTotalHeight/2.0 - padY/2.0, lineWidth + padX * 2.0, lineTotalHeight + padY);
        CGFloat radius = 16.0;
        CGPathRef roundPath = CGPathCreateWithRoundedRect(boxRect, radius, radius, NULL);
        CGContextAddPath(ctx, roundPath);
        CGContextSetFillColorWithColor(ctx, boxColor);
        CGContextFillPath(ctx);
        CGPathRelease(roundPath);
        CGContextRestoreGState(ctx);
    }
    
    // Draw outline stroke if requested
    if (strokeColor && strokeWidth > 0.0) {
        CGContextSaveGState(ctx);
        CGContextSetTextDrawingMode(ctx, kCGTextStroke);
        CGContextSetStrokeColorWithColor(ctx, strokeColor);
        CGContextSetLineWidth(ctx, strokeWidth);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
        CGContextSetTextPosition(ctx, originX, originY);
        CTLineDraw(line, ctx);
        CGContextRestoreGState(ctx);
    }
    
    // Draw fill text
    CGContextSaveGState(ctx);
    CGContextSetTextDrawingMode(ctx, kCGTextFill);
    CGContextSetFillColorWithColor(ctx, fillColor);
    CGContextSetTextPosition(ctx, originX, originY);
    CTLineDraw(line, ctx);
    CGContextRestoreGState(ctx);
    
    CFRelease(line);
    CFRelease(attrStr);
    CFRelease(font);
}

// Draw starry sky
static void drawStarfield(CGContextRef ctx, int frame, CGFloat alpha) {
    CGContextSaveGState(ctx);
    for (int i = 0; i < 150; i++) {
        double rx = pseudoRand(i * 17 + 1) * WIDTH;
        double ry = pseudoRand(i * 29 + 3) * HEIGHT;
        double rsize = 1.5 + pseudoRand(i * 43) * 3.0;
        double twinkle = 0.5 + 0.5 * sin((double)frame * 0.15 + (double)i * 0.8);
        CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, alpha * twinkle * (0.4 + 0.6 * pseudoRand(i * 11)));
        CGContextFillEllipseInRect(ctx, CGRectMake(rx, ry, rsize, rsize));
    }
    CGContextRestoreGState(ctx);
}

// Draw Earth globe
static void drawEarthGlobe(CGContextRef ctx, CGPoint center, CGFloat radius, double rotationAngle, CGFloat shadowTerminator, BOOL isStopped, int freezeShockFrame) {
    CGContextSaveGState(ctx);
    
    // Outer atmospheric glow halo
    CGFloat haloR = radius + 35.0;
    CGContextSetRGBFillColor(ctx, 0.15, 0.65, 1.0, 0.35);
    CGContextFillEllipseInRect(ctx, CGRectMake(center.x - haloR, center.y - haloR, haloR * 2, haloR * 2));
    
    // Globe clipping path
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x - radius, center.y - radius, radius * 2, radius * 2));
    CGContextClip(ctx);
    
    // Ocean base
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat oceanColors[] = {
        0.05, 0.25, 0.65, 1.0,
        0.02, 0.12, 0.38, 1.0
    };
    CGFloat oceanLocations[] = { 0.0, 1.0 };
    CGGradientRef oceanGrad = CGGradientCreateWithColorComponents(cs, oceanColors, oceanLocations, 2);
    CGContextDrawRadialGradient(ctx, oceanGrad, CGPointMake(center.x - radius * 0.3, center.y + radius * 0.3), 10.0,
                                center, radius, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(oceanGrad);
    
    // Draw Continents (projected rotating landmasses)
    CGContextSetRGBFillColor(ctx, 0.18, 0.55, 0.22, 1.0); // vibrant green/earth
    
    // Multiple continent latitude bands
    for (int band = 0; band < 7; band++) {
        double latAngle = -0.7 + band * 0.22;
        double bandY = center.y + radius * sin(latAngle);
        double bandRadius = radius * cos(latAngle);
        if (bandRadius <= 0) continue;
        
        for (int c = 0; c < 4; c++) {
            double baseLon = c * (M_PI / 2.0) + (band % 2) * 0.4;
            double lon = baseLon + rotationAngle;
            double sinLon = sin(lon);
            double cosLon = cos(lon);
            
            // Only draw if on front hemisphere
            if (cosLon > -0.2) {
                double projX = center.x + bandRadius * sinLon;
                double width = 80.0 + 40.0 * pseudoRand(band * 10 + c) * cosLon;
                double height = 50.0 + 30.0 * pseudoRand(band * 20 + c);
                
                CGContextSaveGState(ctx);
                CGContextSetRGBFillColor(ctx, 0.20 + 0.1 * pseudoRand(band), 0.52 + 0.1 * pseudoRand(c), 0.24, 0.95);
                CGContextFillEllipseInRect(ctx, CGRectMake(projX - width/2.0, bandY - height/2.0, width, height));
                CGContextRestoreGState(ctx);
            }
        }
    }
    
    // Clouds layer (swirling white)
    CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 0.45);
    for (int cl = 0; cl < 5; cl++) {
        double cloudLon = cl * 1.3 + rotationAngle * 1.15;
        double cosC = cos(cloudLon);
        if (cosC > -0.1) {
            double cloudX = center.x + radius * 0.85 * sin(cloudLon);
            double cloudY = center.y + (cl - 2) * 80.0;
            CGContextFillEllipseInRect(ctx, CGRectMake(cloudX - 90, cloudY - 25, 180, 50));
        }
    }
    
    // Terminator shadow across right side of the planet for cinematic drama
    CGFloat shadowColors[] = {
        0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.88
    };
    CGFloat shadowLocs[] = { 0.45, 1.0 };
    CGGradientRef shadowGrad = CGGradientCreateWithColorComponents(cs, shadowColors, shadowLocs, 2);
    CGContextDrawLinearGradient(ctx, shadowGrad, CGPointMake(center.x - radius, center.y), CGPointMake(center.x + radius, center.y), 0);
    CGGradientRelease(shadowGrad);
    
    CGColorSpaceRelease(cs);
    CGContextRestoreGState(ctx);
    
    // If freeze shockwave active, draw radial impact rings
    if (isStopped && freezeShockFrame >= 0 && freezeShockFrame < 45) {
        CGContextSaveGState(ctx);
        double shockProgress = (double)freezeShockFrame / 45.0;
        CGFloat shockR = radius + shockProgress * 280.0;
        CGFloat shockAlpha = (1.0 - shockProgress) * 0.85;
        
        CGContextSetRGBStrokeColor(ctx, 1.0, 0.85, 0.2, shockAlpha);
        CGContextSetLineWidth(ctx, 8.0 * (1.0 - shockProgress));
        CGContextStrokeEllipseInRect(ctx, CGRectMake(center.x - shockR, center.y - shockR, shockR * 2, shockR * 2));
        
        // Screech sparks at equator
        for (int sp = 0; sp < 16; sp++) {
            double ang = sp * (M_PI * 2.0 / 16.0);
            double dist = radius + shockProgress * 180.0 * (0.8 + 0.4 * pseudoRand(sp));
            double sx = center.x + dist * cos(ang);
            double sy = center.y + dist * sin(ang);
            CGContextSetRGBFillColor(ctx, 1.0, 0.4, 0.1, shockAlpha);
            CGContextFillEllipseInRect(ctx, CGRectMake(sx - 4, sy - 4, 8, 8));
        }
        CGContextRestoreGState(ctx);
    }
}

// Stickman drawing function with articulation and expression
typedef enum {
    EXPR_CURIOUS,
    EXPR_SHOCKED,
    EXPR_SCREAMING,
    EXPR_JAW_DROP,
    EXPR_PANIC,
    EXPR_CONFIDENT
} StickExpression;

static void drawStickman(CGContextRef ctx,
                         CGPoint pos,
                         CGFloat scale,
                         double bodyAngle,
                         double leftArmAngle1, double leftArmAngle2,
                         double rightArmAngle1, double rightArmAngle2,
                         double leftLegAngle1, double leftLegAngle2,
                         double rightLegAngle1, double rightLegAngle2,
                         StickExpression expr,
                         BOOL hasAstronautHelmet,
                         BOOL hasCape,
                         CGFloat capeFlutter,
                         CGColorRef stickColor,
                         CGFloat lineThickness) {
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, pos.x, pos.y);
    CGContextRotateCTM(ctx, bodyAngle);
    CGContextScaleCTM(ctx, scale, scale);
    
    CGContextSetStrokeColorWithColor(ctx, stickColor);
    CGContextSetFillColorWithColor(ctx, stickColor);
    CGContextSetLineWidth(ctx, lineThickness);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    
    // Head center is at (0, 75), radius 24
    CGPoint headCenter = CGPointMake(0, 75);
    CGFloat headR = 24.0;
    
    // Draw Cape/Scarf if enabled
    if (hasCape) {
        CGContextSaveGState(ctx);
        CGContextSetRGBFillColor(ctx, 0.9, 0.15, 0.2, 0.9);
        CGMutablePathRef cape = CGPathCreateMutable();
        CGPathMoveToPoint(cape, NULL, 0, 50);
        CGPathAddQuadCurveToPoint(cape, NULL, -45 + capeFlutter * 15.0, 30, -70 + capeFlutter * 25.0, -10 + sin(capeFlutter) * 12.0);
        CGPathAddLineToPoint(cape, NULL, -60 + capeFlutter * 20.0, -25);
        CGPathAddQuadCurveToPoint(cape, NULL, -35, 15, 0, 40);
        CGPathCloseSubpath(cape);
        CGContextAddPath(ctx, cape);
        CGContextFillPath(ctx);
        CGPathRelease(cape);
        CGContextRestoreGState(ctx);
    }
    
    // Head circle
    CGContextStrokeEllipseInRect(ctx, CGRectMake(headCenter.x - headR, headCenter.y - headR, headR * 2, headR * 2));
    
    // Facial expressions
    if (expr == EXPR_CURIOUS) {
        // Two simple eye dots + small smile
        CGContextFillEllipseInRect(ctx, CGRectMake(-8, 77, 4, 4));
        CGContextFillEllipseInRect(ctx, CGRectMake(4, 77, 4, 4));
        CGContextMoveToPoint(ctx, -5, 68);
        CGContextAddQuadCurveToPoint(ctx, 0, 64, 5, 68);
        CGContextStrokePath(ctx);
    } else if (expr == EXPR_SHOCKED || expr == EXPR_PANIC) {
        // Wide circle eyes + open O mouth
        CGContextStrokeEllipseInRect(ctx, CGRectMake(-12, 74, 8, 8));
        CGContextStrokeEllipseInRect(ctx, CGRectMake(4, 74, 8, 8));
        CGContextStrokeEllipseInRect(ctx, CGRectMake(-6, 62, 12, 8));
        // Sweat drop
        CGContextSaveGState(ctx);
        CGContextSetRGBFillColor(ctx, 0.3, 0.7, 1.0, 0.9);
        CGContextFillEllipseInRect(ctx, CGRectMake(16, 82, 6, 9));
        CGContextRestoreGState(ctx);
    } else if (expr == EXPR_JAW_DROP) {
        // Huge elongated cartoon jaw drop
        CGContextStrokeEllipseInRect(ctx, CGRectMake(-14, 75, 10, 10));
        CGContextStrokeEllipseInRect(ctx, CGRectMake(4, 75, 10, 10));
        // Enormous dropped jaw down past neck
        CGContextSaveGState(ctx);
        CGContextSetRGBFillColor(ctx, 0.1, 0.1, 0.1, 1.0);
        CGMutablePathRef jaw = CGPathCreateMutable();
        CGPathMoveToPoint(jaw, NULL, -12, 66);
        CGPathAddLineToPoint(jaw, NULL, 12, 66);
        CGPathAddQuadCurveToPoint(jaw, NULL, 15, 10, 0, 8);
        CGPathAddQuadCurveToPoint(jaw, NULL, -15, 10, -12, 66);
        CGPathCloseSubpath(jaw);
        CGContextAddPath(ctx, jaw);
        CGContextFillPath(ctx);
        CGContextStrokePath(ctx);
        CGPathRelease(jaw);
        // Huge sweat drops
        CGContextSetRGBFillColor(ctx, 0.2, 0.7, 1.0, 0.95);
        CGContextFillEllipseInRect(ctx, CGRectMake(22, 90, 8, 14));
        CGContextFillEllipseInRect(ctx, CGRectMake(-28, 90, 8, 14));
        CGContextRestoreGState(ctx);
    } else if (expr == EXPR_SCREAMING) {
        // Angle eyebrows + screaming teeth mouth
        CGContextMoveToPoint(ctx, -12, 85); CGContextAddLineToPoint(ctx, -4, 81);
        CGContextMoveToPoint(ctx, 12, 85); CGContextAddLineToPoint(ctx, 4, 81);
        CGContextStrokePath(ctx);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(-10, 60, 20, 14));
    } else if (expr == EXPR_CONFIDENT) {
        // Determined eyes looking up
        CGContextMoveToPoint(ctx, -10, 77); CGContextAddLineToPoint(ctx, -4, 79);
        CGContextMoveToPoint(ctx, 4, 79); CGContextAddLineToPoint(ctx, 10, 77);
        CGContextStrokePath(ctx);
    }
    
    // Astronaut Helmet if enabled
    if (hasAstronautHelmet) {
        CGContextSaveGState(ctx);
        CGFloat helmR = headR + 10.0;
        CGContextSetRGBStrokeColor(ctx, 0.85, 0.9, 1.0, 0.9);
        CGContextSetLineWidth(ctx, 3.5);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(headCenter.x - helmR, headCenter.y - helmR, helmR * 2, helmR * 2));
        // Glass glare reflection
        CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.6);
        CGContextSetLineWidth(ctx, 2.5);
        CGContextAddArc(ctx, headCenter.x, headCenter.y, helmR - 4, M_PI * 0.6, M_PI * 0.9, 0);
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);
    }
    
    // Torso / Spine: (0, 51) to (0, -10)
    CGPoint neck = CGPointMake(0, 51);
    CGPoint pelvis = CGPointMake(0, -10);
    CGContextMoveToPoint(ctx, neck.x, neck.y);
    CGContextAddLineToPoint(ctx, pelvis.x, pelvis.y);
    CGContextStrokePath(ctx);
    
    // Left Arm (upper + forearm)
    CGPoint shoulder = CGPointMake(0, 42);
    CGFloat armLen1 = 28.0, armLen2 = 26.0;
    CGPoint lElbow = CGPointMake(shoulder.x + armLen1 * cos(leftArmAngle1), shoulder.y + armLen1 * sin(leftArmAngle1));
    CGPoint lHand = CGPointMake(lElbow.x + armLen2 * cos(leftArmAngle2), lElbow.y + armLen2 * sin(leftArmAngle2));
    CGContextMoveToPoint(ctx, shoulder.x, shoulder.y);
    CGContextAddLineToPoint(ctx, lElbow.x, lElbow.y);
    CGContextAddLineToPoint(ctx, lHand.x, lHand.y);
    CGContextStrokePath(ctx);
    
    // Right Arm (upper + forearm)
    CGPoint rElbow = CGPointMake(shoulder.x + armLen1 * cos(rightArmAngle1), shoulder.y + armLen1 * sin(rightArmAngle1));
    CGPoint rHand = CGPointMake(rElbow.x + armLen2 * cos(rightArmAngle2), rElbow.y + armLen2 * sin(rightArmAngle2));
    CGContextMoveToPoint(ctx, shoulder.x, shoulder.y);
    CGContextAddLineToPoint(ctx, rElbow.x, rElbow.y);
    CGContextAddLineToPoint(ctx, rHand.x, rHand.y);
    CGContextStrokePath(ctx);
    
    // Left Leg (thigh + calf)
    CGFloat legLen1 = 34.0, legLen2 = 32.0;
    CGPoint lKnee = CGPointMake(pelvis.x + legLen1 * cos(leftLegAngle1), pelvis.y + legLen1 * sin(leftLegAngle1));
    CGPoint lFoot = CGPointMake(lKnee.x + legLen2 * cos(leftLegAngle2), lKnee.y + legLen2 * sin(leftLegAngle2));
    CGContextMoveToPoint(ctx, pelvis.x, pelvis.y);
    CGContextAddLineToPoint(ctx, lKnee.x, lKnee.y);
    CGContextAddLineToPoint(ctx, lFoot.x, lFoot.y);
    CGContextStrokePath(ctx);
    
    // Right Leg (thigh + calf)
    CGPoint rKnee = CGPointMake(pelvis.x + legLen1 * cos(rightLegAngle1), pelvis.y + legLen1 * sin(rightLegAngle1));
    CGPoint rFoot = CGPointMake(rKnee.x + legLen2 * cos(rightLegAngle2), rKnee.y + legLen2 * sin(rightLegAngle2));
    CGContextMoveToPoint(ctx, pelvis.x, pelvis.y);
    CGContextAddLineToPoint(ctx, rKnee.x, rKnee.y);
    CGContextAddLineToPoint(ctx, rFoot.x, rFoot.y);
    CGContextStrokePath(ctx);
    
    CGContextRestoreGState(ctx);
}

// Draw a stick car
static void drawStickCar(CGContextRef ctx, CGPoint pos, CGFloat scale, double tiltAngle, BOOL isCrashing) {
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, pos.x, pos.y);
    CGContextRotateCTM(ctx, tiltAngle);
    CGContextScaleCTM(ctx, scale, scale);
    
    CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 1.0);
    CGContextSetLineWidth(ctx, 5.0);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    
    // Car body chassis
    CGMutablePathRef car = CGPathCreateMutable();
    CGPathMoveToPoint(car, NULL, -90, 0);
    CGPathAddLineToPoint(car, NULL, 90, 0);
    CGPathAddLineToPoint(car, NULL, 90, 30);
    CGPathAddLineToPoint(car, NULL, 40, 30);
    CGPathAddLineToPoint(car, NULL, 10, 65);
    CGPathAddLineToPoint(car, NULL, -50, 65);
    CGPathAddLineToPoint(car, NULL, -70, 30);
    CGPathAddLineToPoint(car, NULL, -90, 30);
    CGPathCloseSubpath(car);
    
    CGContextSaveGState(ctx);
    CGContextSetRGBFillColor(ctx, 0.85, 0.25, 0.2, 0.9); // sport red car
    CGContextAddPath(ctx, car);
    CGContextFillPath(ctx);
    CGContextAddPath(ctx, car);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
    CGPathRelease(car);
    
    // Wheels
    CGContextSetRGBFillColor(ctx, 0.15, 0.15, 0.15, 1.0);
    CGContextFillEllipseInRect(ctx, CGRectMake(-65, -18, 36, 36));
    CGContextStrokeEllipseInRect(ctx, CGRectMake(-65, -18, 36, 36));
    CGContextFillEllipseInRect(ctx, CGRectMake(35, -18, 36, 36));
    CGContextStrokeEllipseInRect(ctx, CGRectMake(35, -18, 36, 36));
    
    // Stick driver inside windshield
    CGContextStrokeEllipseInRect(ctx, CGRectMake(-20, 38, 16, 16));
    
    // Headlights beam
    CGContextSaveGState(ctx);
    CGContextSetRGBFillColor(ctx, 1.0, 0.95, 0.5, 0.35);
    CGMutablePathRef beam = CGPathCreateMutable();
    CGPathMoveToPoint(beam, NULL, 90, 15);
    CGPathAddLineToPoint(beam, NULL, 280, 50);
    CGPathAddLineToPoint(beam, NULL, 260, -20);
    CGPathCloseSubpath(beam);
    CGContextAddPath(ctx, beam);
    CGContextFillPath(ctx);
    CGPathRelease(beam);
    CGContextRestoreGState(ctx);
    
    // Smoke / sparks if crashing
    if (isCrashing) {
        CGContextSaveGState(ctx);
        for (int p = 0; p < 8; p++) {
            double px = -90 - p * 15.0;
            double py = 10 + sin(p * 2.0) * 15.0;
            CGContextSetRGBFillColor(ctx, 0.8, 0.8, 0.8, 0.6 - p * 0.06);
            CGContextFillEllipseInRect(ctx, CGRectMake(px, py, 20 + p * 4, 20 + p * 4));
        }
        CGContextRestoreGState(ctx);
    }
    
    CGContextRestoreGState(ctx);
}

// Draw a stick dog
static void drawStickDog(CGContextRef ctx, CGPoint pos, CGFloat scale, double angle, BOOL isFlying) {
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, pos.x, pos.y);
    CGContextRotateCTM(ctx, angle);
    CGContextScaleCTM(ctx, scale, scale);
    
    CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 1.0);
    CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 1.0);
    CGContextSetLineWidth(ctx, 4.0);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    
    // Body horizontal: (-25, 0) to (25, 0)
    CGContextMoveToPoint(ctx, -25, 0); CGContextAddLineToPoint(ctx, 25, 0);
    CGContextStrokePath(ctx);
    
    // Head at (35, 15)
    CGContextStrokeEllipseInRect(ctx, CGRectMake(27, 7, 16, 16));
    // Ear
    CGContextMoveToPoint(ctx, 33, 23); CGContextAddLineToPoint(ctx, 28, 28); CGContextStrokePath(ctx);
    // Tail
    CGContextMoveToPoint(ctx, -25, 0); CGContextAddLineToPoint(ctx, -38, 15); CGContextStrokePath(ctx);
    
    // Legs
    if (isFlying) {
        // Superman stretched out legs
        CGContextMoveToPoint(ctx, 20, 0); CGContextAddLineToPoint(ctx, 40, -5);
        CGContextMoveToPoint(ctx, -20, 0); CGContextAddLineToPoint(ctx, -40, -5);
    } else {
        CGContextMoveToPoint(ctx, 15, 0); CGContextAddLineToPoint(ctx, 15, -20);
        CGContextMoveToPoint(ctx, -15, 0); CGContextAddLineToPoint(ctx, -15, -20);
    }
    CGContextStrokePath(ctx);
    
    CGContextRestoreGState(ctx);
}

// Render Master Frame Router
static void renderFrame(CGContextRef ctx, int f) {
    double t = (double)f / (double)FPS;
    
    // Clean black base
    CGContextSetRGBFillColor(ctx, 0.02, 0.02, 0.04, 1.0);
    CGContextFillRect(ctx, CGRectMake(0, 0, WIDTH, HEIGHT));
    
    // Colors for text styling
    CGColorRef whiteCol = CGColorCreateSRGB(1.0, 1.0, 1.0, 1.0);
    CGColorRef yellowCol = CGColorCreateSRGB(1.0, 0.88, 0.15, 1.0);
    CGColorRef redCol = CGColorCreateSRGB(1.0, 0.22, 0.22, 1.0);
    CGColorRef cyanCol = CGColorCreateSRGB(0.2, 0.9, 1.0, 1.0);
    CGColorRef darkBoxCol = CGColorCreateSRGB(0.0, 0.0, 0.0, 0.75);
    CGColorRef redBoxCol = CGColorCreateSRGB(0.8, 0.1, 0.1, 0.85);
    CGColorRef blackStrokeCol = CGColorCreateSRGB(0.0, 0.0, 0.0, 0.9);
    
    // ==========================================
    // SCENE 1: 0 - 119 (0.0s - 4.0s)
    // "What if Earth stopped spinning... for just three seconds?"
    // ==========================================
    if (f < 120) {
        // Deep space background with subtle nebula
        drawStarfield(ctx, f, 1.0);
        
        BOOL isFrozen = (f >= 75); // 2.5s freeze
        int shockAge = isFrozen ? (f - 75) : -1;
        
        // Earth rotation
        double rotSpeed = isFrozen ? 0.0 : 0.035;
        double currentRot = (f < 75) ? (f * 0.035) : (75 * 0.035);
        
        // Earth center & zoom
        double zoom = 1.0 + 0.12 * easeOutCubic((double)f / 120.0);
        CGPoint earthCenter = CGPointMake(WIDTH / 2.0, 1020);
        
        // Dynamic camera shake on freeze
        if (isFrozen && shockAge < 20) {
            double shakeMag = (1.0 - (double)shockAge / 20.0) * 16.0;
            earthCenter.x += sin(shockAge * 1.8) * shakeMag;
            earthCenter.y += cos(shockAge * 2.2) * shakeMag;
        }
        
        drawEarthGlobe(ctx, earthCenter, 310 * zoom, currentRot, 0.85, isFrozen, shockAge);
        
        // Stickman Astronaut floating in space
        CGPoint astroPos = CGPointMake(260 + sin((double)f * 0.05) * 15.0, 1420 + cos((double)f * 0.04) * 20.0);
        double astroAngle = sin((double)f * 0.04) * 0.15;
        StickExpression astroExpr = isFrozen ? EXPR_SHOCKED : EXPR_CURIOUS;
        
        if (isFrozen) {
            // Recoil jerk on freeze!
            double jerk = sin((f - 75) * 0.4) * exp(-(f - 75) * 0.08);
            astroAngle += jerk * 0.6;
            astroPos.x += jerk * 30.0;
        }
        
        drawStickman(ctx, astroPos, 1.35, astroAngle,
                     -M_PI * 0.7 + sin((double)f * 0.1) * 0.3, -M_PI * 0.5,
                     -M_PI * 0.2 + (isFrozen ? -0.8 : sin((double)f * 0.08) * 0.4), -M_PI * 0.3,
                     -M_PI * 0.6, -M_PI * 0.5,
                     -M_PI * 0.4, -M_PI * 0.5,
                     astroExpr, YES, NO, 0, whiteCol, 4.5);
        
        // Main Question Title Box
        drawStyledText(ctx, @"WHAT IF EARTH STOPPED SPINNING?", @"HelveticaNeue-Bold", 44.0,
                       CGPointMake(WIDTH / 2.0, 1720), whiteCol, blackStrokeCol, 6.0, YES, darkBoxCol);
        
        // "FOR JUST THREE SECONDS" Pop-in
        if (f >= 75) {
            double popProgress = clamp((double)(f - 75) / 12.0, 0.0, 1.0);
            double popScale = easeOutCubic(popProgress);
            CGFloat fSize = 64.0 * popScale;
            drawStyledText(ctx, @"3 SECONDS", @"Impact", fSize,
                           CGPointMake(WIDTH / 2.0, 1590), yellowCol, redCol, 8.0, YES, redBoxCol);
            
            drawStyledText(ctx, @"[ SUDDEN ROTATIONAL FREEZE ]", @"HelveticaNeue-Bold", 32.0,
                           CGPointMake(WIDTH / 2.0, 260), cyanCol, blackStrokeCol, 4.0, YES, darkBoxCol);
        }
    }
    // ==========================================
    // SCENE 2: 120 - 269 (4.0s - 9.0s)
    // "The planet would stop. But everything on it would keep moving."
    // ==========================================
    else if (f < 270) {
        int sf = f - 120; // scene frame
        
        // City backdrop
        CGContextSaveGState(ctx);
        // Sky gradient
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGFloat skyColors[] = { 0.12, 0.28, 0.58, 1.0, 0.65, 0.82, 0.95, 1.0 };
        CGFloat skyLocs[] = { 0.0, 1.0 };
        CGGradientRef skyGrad = CGGradientCreateWithColorComponents(cs, skyColors, skyLocs, 2);
        CGContextDrawLinearGradient(ctx, skyGrad, CGPointMake(0, HEIGHT), CGPointMake(0, 0), 0);
        CGGradientRelease(skyGrad);
        CGColorSpaceRelease(cs);
        
        // Camera shake from inertia stop
        double shake = (sf < 45) ? sin(sf * 1.5) * (45 - sf) * 0.5 : 0.0;
        CGContextTranslateCTM(ctx, shake, 0);
        
        // Skyscrapers in background
        for (int b = 0; b < 9; b++) {
            double bx = b * 130 - 30;
            double bw = 115;
            double bh = 600 + (b % 4) * 160 + pseudoRand(b * 31) * 140;
            CGContextSetRGBFillColor(ctx, 0.25 + (b % 3) * 0.05, 0.32 + (b % 3) * 0.05, 0.42 + (b % 3) * 0.05, 1.0);
            CGContextFillRect(ctx, CGRectMake(bx, 420, bw, bh));
            
            // Lit windows
            CGContextSetRGBFillColor(ctx, 1.0, 0.95, 0.6, 0.8);
            for (int wy = 450; wy < 420 + bh - 40; wy += 45) {
                for (int wx = bx + 15; wx < bx + bw - 20; wx += 28) {
                    if (pseudoRand(wx * 7 + wy) > 0.4) {
                        CGContextFillRect(ctx, CGRectMake(wx, wy, 16, 24));
                    }
                }
            }
        }
        
        // Ground road and sidewalk
        CGContextSetRGBFillColor(ctx, 0.15, 0.15, 0.18, 1.0); // asphalt
        CGContextFillRect(ctx, CGRectMake(0, 0, WIDTH, 420));
        CGContextSetRGBFillColor(ctx, 0.45, 0.45, 0.48, 1.0); // sidewalk
        CGContextFillRect(ctx, CGRectMake(0, 380, WIDTH, 50));
        
        // Road white lane markings
        CGContextSetRGBFillColor(ctx, 0.95, 0.95, 0.95, 0.9);
        for (int rx = 0; rx < WIDTH; rx += 140) {
            CGContextFillRect(ctx, CGRectMake(rx, 200, 80, 14));
        }
        
        // Street lamppost at x=340
        CGFloat poleX = 340.0;
        CGContextSetRGBStrokeColor(ctx, 0.8, 0.8, 0.8, 1.0);
        CGContextSetLineWidth(ctx, 10.0);
        CGContextMoveToPoint(ctx, poleX, 420);
        // Bending lamppost under inertia tension!
        double poleBend = clamp((double)sf * 1.2, 0.0, 38.0);
        CGContextAddQuadCurveToPoint(ctx, poleX + poleBend * 0.5, 620, poleX + poleBend, 820);
        CGContextStrokePath(ctx);
        // Lamp head
        CGContextFillEllipseInRect(ctx, CGRectMake(poleX + poleBend - 20, 810, 45, 25));
        
        // INERTIA EVENT:
        // Stickman clutching pole horizontally like a flag in hurricane!
        double stickX = poleX + poleBend + 65.0;
        double stickY = 620.0 + sin((double)sf * 0.4) * 8.0;
        
        // Body streaming completely horizontal (+90 deg)
        drawStickman(ctx, CGPointMake(stickX, stickY), 1.5, -M_PI * 0.48,
                     -M_PI * 0.1, -M_PI * 0.1,  // arms outstretched holding pole
                     -M_PI * 0.05, -M_PI * 0.05,
                     -M_PI * 0.45, -M_PI * 0.45, // legs trailing in horizontal wind
                     -M_PI * 0.52, -M_PI * 0.52,
                     EXPR_PANIC, NO, NO, 0, whiteCol, 5.0);
        
        // Flying coffee cup & splashed coffee droplets!
        double cupX = stickX + 180.0 + sf * 12.0;
        double cupY = 720.0 + sin(sf * 0.2) * 50.0 - (sf * sf * 0.08);
        CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 1.0);
        CGContextFillRect(ctx, CGRectMake(cupX, cupY, 24, 30)); // cup
        // Brown splash droplets
        CGContextSetRGBFillColor(ctx, 0.45, 0.25, 0.12, 0.9);
        for (int d = 0; d < 8; d++) {
            double dx = cupX - 40 - d * 18.0;
            double dy = cupY + 15 + sin(d * 1.5 + sf * 0.3) * 25.0;
            CGContextFillEllipseInRect(ctx, CGRectMake(dx, dy, 12, 12));
        }
        
        // Flying stick dog flying horizontally across screen
        double dogX = 120.0 + sf * 16.0;
        double dogY = 820.0 + sin(sf * 0.15) * 35.0;
        if (dogX < WIDTH + 100) {
            drawStickDog(ctx, CGPointMake(dogX, dogY), 1.6, 0.15, YES);
        }
        
        // Stick-car screeching, tilting and skidding forward!
        double carX = 220.0 + clamp((double)sf * 8.0, 0.0, 480.0);
        double carTilt = clamp((double)sf * 0.02, 0.0, 0.35);
        drawStickCar(ctx, CGPointMake(carX, 220), 1.5, carTilt, YES);
        
        // Supersonic horizontal speed lines across screen
        CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.5);
        CGContextSetLineWidth(ctx, 3.0);
        for (int sl = 0; sl < 12; sl++) {
            double sy = 400 + sl * 80 + pseudoRand(sl) * 40;
            double sx1 = fmod(sf * 35.0 + sl * 120, WIDTH);
            CGContextMoveToPoint(ctx, sx1, sy);
            CGContextAddLineToPoint(ctx, sx1 + 180, sy);
            CGContextStrokePath(ctx);
        }
        
        CGContextRestoreGState(ctx);
        
        // HUD / Titles
        drawStyledText(ctx, @"THE PLANET STOPS...", @"HelveticaNeue-Bold", 40.0,
                       CGPointMake(WIDTH / 2.0, 1750), whiteCol, blackStrokeCol, 6.0, YES, darkBoxCol);
        drawStyledText(ctx, @"EVERYTHING ELSE KEEPS MOVING!", @"Impact", 56.0,
                       CGPointMake(WIDTH / 2.0, 1630), redCol, whiteCol, 4.0, YES, redBoxCol);
        
        drawStyledText(ctx, @"NEWTON'S FIRST LAW: INERTIA", @"HelveticaNeue-Bold", 32.0,
                       CGPointMake(WIDTH / 2.0, 260), yellowCol, blackStrokeCol, 5.0, YES, darkBoxCol);
    }
    // ==========================================
    // SCENE 3: 270 - 449 (9.0s - 15.0s)
    // "At the equator, the ground moves at about a thousand miles per hour."
    // ==========================================
    else if (f < 450) {
        int sf = f - 270;
        
        // Stormy equatorial atmosphere
        CGContextSaveGState(ctx);
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGFloat stormColors[] = { 0.18, 0.14, 0.22, 1.0, 0.55, 0.42, 0.32, 1.0 };
        CGFloat stormLocs[] = { 0.0, 1.0 };
        CGGradientRef stormGrad = CGGradientCreateWithColorComponents(cs, stormColors, stormLocs, 2);
        CGContextDrawLinearGradient(ctx, stormGrad, CGPointMake(0, HEIGHT), CGPointMake(0, 0), 0);
        CGGradientRelease(stormGrad);
        CGColorSpaceRelease(cs);
        
        // Ground terrain
        CGContextSetRGBFillColor(ctx, 0.45, 0.38, 0.28, 1.0);
        CGContextFillRect(ctx, CGRectMake(0, 0, WIDTH, 360));
        
        // Equator Line painted on ground
        CGContextSetRGBStrokeColor(ctx, 1.0, 0.2, 0.2, 0.9);
        CGContextSetLineWidth(ctx, 14.0);
        CGContextMoveToPoint(ctx, 0, 360);
        CGContextAddLineToPoint(ctx, WIDTH, 360);
        CGContextStrokePath(ctx);
        
        // Supersonic 1000 MPH Wind Shockwaves
        for (int w = 0; w < 16; w++) {
            double wy = 380 + w * 85;
            double wx = fmod(sf * 65.0 + w * 180, WIDTH + 400) - 200;
            CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.45);
            CGContextSetLineWidth(ctx, 4.0);
            CGContextMoveToPoint(ctx, wx, wy);
            CGContextAddLineToPoint(ctx, wx + 260, wy);
            CGContextStrokePath(ctx);
            
            // Transonic vapor cone
            if (w % 4 == 0) {
                CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 0.25);
                CGMutablePathRef cone = CGPathCreateMutable();
                CGPathMoveToPoint(cone, NULL, wx + 200, wy);
                CGPathAddLineToPoint(cone, NULL, wx, wy + 40);
                CGPathAddLineToPoint(cone, NULL, wx, wy - 40);
                CGPathCloseSubpath(cone);
                CGContextAddPath(ctx, cone);
                CGContextFillPath(ctx);
                CGPathRelease(cone);
            }
        }
        
        // Palm trees bent 90 degrees horizontal!
        for (int p = 0; p < 3; p++) {
            CGFloat tx = 180 + p * 320;
            CGContextSetRGBStrokeColor(ctx, 0.45, 0.3, 0.15, 1.0);
            CGContextSetLineWidth(ctx, 18.0);
            CGContextMoveToPoint(ctx, tx, 360);
            // Bend horizontal
            CGContextAddQuadCurveToPoint(ctx, tx + 60, 480, tx + 220, 490);
            CGContextStrokePath(ctx);
            // Fronds flying off
            CGContextSetRGBStrokeColor(ctx, 0.2, 0.65, 0.2, 0.9);
            CGContextSetLineWidth(ctx, 8.0);
            for (int fr = 0; fr < 5; fr++) {
                CGContextMoveToPoint(ctx, tx + 220, 490);
                CGContextAddLineToPoint(ctx, tx + 320 + fr * 25, 490 + (fr - 2) * 20);
                CGContextStrokePath(ctx);
            }
        }
        
        // Flying building roof & bricks!
        double roofX = 300.0 + sf * 14.0;
        double roofY = 700.0 + sf * 4.0;
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, roofX, roofY);
        CGContextRotateCTM(ctx, sf * 0.1);
        CGContextSetRGBFillColor(ctx, 0.75, 0.3, 0.2, 0.95);
        CGMutablePathRef roof = CGPathCreateMutable();
        CGPathMoveToPoint(roof, NULL, -80, 0);
        CGPathAddLineToPoint(roof, NULL, 80, 0);
        CGPathAddLineToPoint(roof, NULL, 0, 70);
        CGPathCloseSubpath(roof);
        CGContextAddPath(ctx, roof);
        CGContextFillPath(ctx);
        CGPathRelease(roof);
        CGContextRestoreGState(ctx);
        
        // Stickman Scientist clinging onto Equator Monument Pole!
        CGFloat monX = 480.0;
        CGContextSetRGBFillColor(ctx, 0.3, 0.3, 0.35, 1.0);
        CGContextFillRect(ctx, CGRectMake(monX - 25, 360, 50, 400));
        
        drawStickman(ctx, CGPointMake(monX + 110, 620), 1.5, -M_PI * 0.48,
                     -M_PI * 0.05, -M_PI * 0.05,
                     -M_PI * 0.05, -M_PI * 0.05,
                     -M_PI * 0.48, -M_PI * 0.48,
                     -M_PI * 0.52, -M_PI * 0.52,
                     EXPR_SCREAMING, NO, YES, sin(sf * 0.8), whiteCol, 5.0);
        
        CGContextRestoreGState(ctx);
        
        // SPEEDOMETER HUD OVERLAY at top
        CGPoint gaugeCenter = CGPointMake(WIDTH / 2.0, 1380);
        CGFloat gaugeR = 170.0;
        
        // Gauge background disc
        CGContextSaveGState(ctx);
        CGContextSetRGBFillColor(ctx, 0.05, 0.08, 0.15, 0.92);
        CGContextFillEllipseInRect(ctx, CGRectMake(gaugeCenter.x - gaugeR - 25, gaugeCenter.y - gaugeR - 25, (gaugeR + 25) * 2, (gaugeR + 25) * 2));
        CGContextSetRGBStrokeColor(ctx, 0.3, 0.8, 1.0, 0.8);
        CGContextSetLineWidth(ctx, 6.0);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(gaugeCenter.x - gaugeR - 25, gaugeCenter.y - gaugeR - 25, (gaugeR + 25) * 2, (gaugeR + 25) * 2));
        
        // Gauge Arc
        CGContextSetLineWidth(ctx, 12.0);
        CGContextSetRGBStrokeColor(ctx, 0.2, 0.9, 0.4, 0.8); // green safe
        CGContextAddArc(ctx, gaugeCenter.x, gaugeCenter.y, gaugeR, M_PI * 0.8, M_PI * 1.5, 0);
        CGContextStrokePath(ctx);
        CGContextSetRGBStrokeColor(ctx, 1.0, 0.2, 0.2, 0.95); // red danger zone
        CGContextAddArc(ctx, gaugeCenter.x, gaugeCenter.y, gaugeR, M_PI * 1.5, M_PI * 2.2, 0);
        CGContextStrokePath(ctx);
        
        // Vibrating needle pinned at 1040 MPH
        double needleAng = M_PI * 2.05 + sin(sf * 1.2) * 0.05;
        CGContextSetRGBStrokeColor(ctx, 1.0, 0.15, 0.15, 1.0);
        CGContextSetLineWidth(ctx, 7.0);
        CGContextMoveToPoint(ctx, gaugeCenter.x, gaugeCenter.y);
        CGContextAddLineToPoint(ctx, gaugeCenter.x + (gaugeR - 10) * cos(needleAng), gaugeCenter.y + (gaugeR - 10) * sin(needleAng));
        CGContextStrokePath(ctx);
        CGContextFillEllipseInRect(ctx, CGRectMake(gaugeCenter.x - 14, gaugeCenter.y - 14, 28, 28));
        CGContextRestoreGState(ctx);
        
        // Digital readout
        drawStyledText(ctx, @"1,040 MPH", @"Impact", 68.0,
                       CGPointMake(WIDTH / 2.0, 1370), redCol, whiteCol, 4.0, NO, NULL);
        drawStyledText(ctx, @"EQUATORIAL ROTATION SPEED", @"HelveticaNeue-Bold", 26.0,
                       CGPointMake(WIDTH / 2.0, 1290), cyanCol, blackStrokeCol, 4.0, NO, NULL);
        
        // Scene Subtitles
        drawStyledText(ctx, @"AT THE EQUATOR: 1,000 MPH", @"HelveticaNeue-Bold", 42.0,
                       CGPointMake(WIDTH / 2.0, 1750), whiteCol, blackStrokeCol, 6.0, YES, darkBoxCol);
        drawStyledText(ctx, @"SUPERSONIC WINDS DESTROY EVERYTHING", @"Impact", 46.0,
                       CGPointMake(WIDTH / 2.0, 1640), yellowCol, blackStrokeCol, 6.0, YES, redBoxCol);
    }
    // ==========================================
    // SCENE 4: 450 - 629 (15.0s - 21.0s)
    // "Oceans would surge across coastlines, reshaping the world in moments."
    // ==========================================
    else if (f < 630) {
        int sf = f - 450;
        
        // Dark turbulent storm sea & sky
        CGContextSaveGState(ctx);
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGFloat seaSkyColors[] = { 0.08, 0.12, 0.22, 1.0, 0.22, 0.35, 0.45, 1.0 };
        CGFloat seaSkyLocs[] = { 0.0, 1.0 };
        CGGradientRef seaSkyGrad = CGGradientCreateWithColorComponents(cs, seaSkyColors, seaSkyLocs, 2);
        CGContextDrawLinearGradient(ctx, seaSkyGrad, CGPointMake(0, HEIGHT), CGPointMake(0, 0), 0);
        CGGradientRelease(seaSkyGrad);
        CGColorSpaceRelease(cs);
        
        // Camera earthquake shake when wave crashes
        double camShake = sin(sf * 0.9) * 12.0 * clamp((double)sf / 80.0, 0.2, 1.0);
        CGContextTranslateCTM(ctx, 0, camShake);
        
        // GARGANTUAN MEGA-TSUNAMI WAVE WALL!
        // The wave rises up from 800 to 1550 as scene progresses
        double wavePeakH = 850.0 + clamp((double)sf * 4.5, 0.0, 680.0);
        
        // Deep water body
        CGMutablePathRef wavePath = CGPathCreateMutable();
        CGPathMoveToPoint(wavePath, NULL, -100, 0);
        CGPathAddLineToPoint(wavePath, NULL, -100, wavePeakH);
        
        // Dramatic curling wave crest
        for (double wx = -100; wx <= WIDTH + 100; wx += 40) {
            double wy = wavePeakH + sin(wx * 0.012 + sf * 0.15) * 60.0 + cos(wx * 0.02) * 35.0;
            CGPathAddLineToPoint(wavePath, NULL, wx, wy);
        }
        CGPathAddLineToPoint(wavePath, NULL, WIDTH + 100, 0);
        CGPathCloseSubpath(wavePath);
        
        CGFloat waveColors[] = {
            0.02, 0.15, 0.35, 1.0,
            0.08, 0.45, 0.65, 0.95
        };
        CGFloat waveLocs[] = { 0.0, 1.0 };
        CGGradientRef waveGrad = CGGradientCreateWithColorComponents(cs, waveColors, waveLocs, 2);
        CGContextAddPath(ctx, wavePath);
        CGContextClip(ctx);
        CGContextDrawLinearGradient(ctx, waveGrad, CGPointMake(0, 0), CGPointMake(0, wavePeakH + 100), 0);
        CGGradientRelease(waveGrad);
        CGPathRelease(wavePath);
        CGColorSpaceRelease(cs);
        CGContextRestoreGState(ctx);
        
        // Massive foaming crest lip with spray particles
        CGContextSaveGState(ctx);
        CGContextSetRGBFillColor(ctx, 0.95, 0.98, 1.0, 0.85);
        for (int fo = 0; fo < 25; fo++) {
            double fx = fo * 48;
            double fy = wavePeakH + sin(fx * 0.012 + sf * 0.15) * 60.0 + 20.0;
            CGContextFillEllipseInRect(ctx, CGRectMake(fx - 25, fy - 25, 60, 50));
            // Flying mist spray
            for (int sp = 0; sp < 3; sp++) {
                double sx = fx + sin(sp + sf * 0.2) * 40.0;
                double sy = fy + 35 + sp * 25.0;
                CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 0.5);
                CGContextFillEllipseInRect(ctx, CGRectMake(sx, sy, 8, 8));
            }
        }
        CGContextRestoreGState(ctx);
        
        // Foreground Coastal Cliff / Pier
        CGContextSetRGBFillColor(ctx, 0.15, 0.12, 0.10, 1.0);
        CGContextFillRect(ctx, CGRectMake(0, 0, WIDTH, 340));
        
        // COASTAL STICKMAN: JAW DROPPED IN UTTER SHOCK!
        CGPoint stickPos = CGPointMake(540, 340);
        drawStickman(ctx, stickPos, 2.0, 0.0,
                     -M_PI * 0.75, -M_PI * 0.85, // hands clamped onto head
                     -M_PI * 0.25, -M_PI * 0.15, // hands clamped onto head
                     -M_PI * 0.55, -M_PI * 0.48, // trembling knees
                     -M_PI * 0.45, -M_PI * 0.52,
                     EXPR_JAW_DROP, NO, NO, 0, whiteCol, 6.0);
        
        // Scene Titles
        drawStyledText(ctx, @"OCEANS SURGE ACROSS COASTLINES", @"HelveticaNeue-Bold", 42.0,
                       CGPointMake(WIDTH / 2.0, 1750), whiteCol, blackStrokeCol, 6.0, YES, darkBoxCol);
        drawStyledText(ctx, @"MEGA-TSUNAMIS RESHAPE THE WORLD", @"Impact", 50.0,
                       CGPointMake(WIDTH / 2.0, 1630), cyanCol, blackStrokeCol, 6.0, YES, darkBoxCol);
        drawStyledText(ctx, @"[ MILES OF INLAND FLOODING ]", @"HelveticaNeue-Bold", 30.0,
                       CGPointMake(WIDTH / 2.0, 240), yellowCol, blackStrokeCol, 4.0, YES, darkBoxCol);
    }
    // ==========================================
    // SCENE 5: 630 - 779 (21.0s - 26.0s)
    // "Then Earth starts spinning again—and the chaos gets even worse."
    // ==========================================
    else if (f < 780) {
        int sf = f - 630;
        
        // Space view returns!
        drawStarfield(ctx, f, 1.0);
        
        // Blinding flash burst on spin restart (sf < 20)
        double flashAlpha = (sf < 25) ? (1.0 - (double)sf / 25.0) : 0.0;
        
        // Camera pullback zoom
        double camZoom = 1.15 - 0.25 * easeOutCubic((double)sf / 150.0);
        CGPoint earthCenter = CGPointMake(WIDTH / 2.0, 1080);
        
        // Earth violently spinning with rapid acceleration!
        double resumeRot = sf * 0.18; // 5x normal speed!
        drawEarthGlobe(ctx, earthCenter, 310 * camZoom, resumeRot, 0.85, NO, -1);
        
        // Rapid chaotic cyclonic swirls
        CGContextSaveGState(ctx);
        for (int cy = 0; cy < 4; cy++) {
            double cAng = cy * (M_PI / 2.0) + resumeRot * 1.5;
            double cx = earthCenter.x + 180 * cos(cAng);
            double cyPos = earthCenter.y + 120 * sin(cAng);
            CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.65);
            CGContextSetLineWidth(ctx, 8.0);
            CGContextAddArc(ctx, cx, cyPos, 45, 0, M_PI * 1.4, 0);
            CGContextStrokePath(ctx);
        }
        CGContextRestoreGState(ctx);
        
        // Expanding cosmic torque shockwave rings
        if (sf < 50) {
            CGContextSaveGState(ctx);
            double prog = (double)sf / 50.0;
            CGFloat ringR = 320 * camZoom + prog * 420.0;
            CGContextSetRGBStrokeColor(ctx, 0.3, 0.9, 1.0, (1.0 - prog) * 0.9);
            CGContextSetLineWidth(ctx, 10.0 * (1.0 - prog));
            CGContextStrokeEllipseInRect(ctx, CGRectMake(earthCenter.x - ringR, earthCenter.y - ringR, ringR * 2, ringR * 2));
            CGContextRestoreGState(ctx);
        }
        
        // Reverse Inertia Split Insets / Chaos indicators:
        // Left inset: Stickman tumbling backwards!
        CGRect insetRect = CGRectMake(80, 280, 420, 320);
        CGContextSaveGState(ctx);
        CGContextSetRGBFillColor(ctx, 0.08, 0.08, 0.12, 0.92);
        CGContextFillRect(ctx, insetRect);
        CGContextSetRGBStrokeColor(ctx, 1.0, 0.2, 0.2, 0.9);
        CGContextSetLineWidth(ctx, 5.0);
        CGContextStrokeRect(ctx, insetRect);
        
        // Tumbling stickman inside inset
        drawStickman(ctx, CGPointMake(290, 440), 1.3, -sf * 0.25,
                     -M_PI * 0.8, -M_PI * 0.3,
                     -M_PI * 0.2, -M_PI * 0.7,
                     -M_PI * 0.6, -M_PI * 0.4,
                     -M_PI * 0.3, -M_PI * 0.5,
                     EXPR_SCREAMING, NO, NO, 0, whiteCol, 4.5);
        CGContextRestoreGState(ctx);
        drawStyledText(ctx, @"REVERSE INERTIA", @"HelveticaNeue-Bold", 24.0,
                       CGPointMake(290, 320), redCol, blackStrokeCol, 4.0, NO, NULL);
        
        // Right inset: Sloshing reversed oceans!
        CGRect insetRect2 = CGRectMake(580, 280, 420, 320);
        CGContextSaveGState(ctx);
        CGContextSetRGBFillColor(ctx, 0.05, 0.15, 0.28, 0.92);
        CGContextFillRect(ctx, insetRect2);
        CGContextSetRGBStrokeColor(ctx, 0.2, 0.8, 1.0, 0.9);
        CGContextSetLineWidth(ctx, 5.0);
        CGContextStrokeRect(ctx, insetRect2);
        // Reverse water wave
        CGContextSetRGBFillColor(ctx, 0.1, 0.5, 0.8, 0.9);
        CGContextFillEllipseInRect(ctx, CGRectMake(580, 360, 420, 180));
        CGContextRestoreGState(ctx);
        drawStyledText(ctx, @"REVERSE SLOSH", @"HelveticaNeue-Bold", 24.0,
                       CGPointMake(790, 320), cyanCol, blackStrokeCol, 4.0, NO, NULL);
        
        // Screen Flash Frame
        if (flashAlpha > 0.0) {
            CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, flashAlpha * 0.8);
            CGContextFillRect(ctx, CGRectMake(0, 0, WIDTH, HEIGHT));
        }
        
        // Titles
        drawStyledText(ctx, @"THEN EARTH SPINS AGAIN...", @"HelveticaNeue-Bold", 42.0,
                       CGPointMake(WIDTH / 2.0, 1750), whiteCol, blackStrokeCol, 6.0, YES, darkBoxCol);
        drawStyledText(ctx, @"AND THE CHAOS GETS EVEN WORSE!", @"Impact", 52.0,
                       CGPointMake(WIDTH / 2.0, 1630), redCol, whiteCol, 4.0, YES, redBoxCol);
        drawStyledText(ctx, @"[ REVERSE ACCELERATION TORQUE ]", @"HelveticaNeue-Bold", 28.0,
                       CGPointMake(WIDTH / 2.0, 640), yellowCol, blackStrokeCol, 4.0, YES, darkBoxCol);
    }
    // ==========================================
    // SCENE 6: 780 - 899 (26.0s - 30.0s)
    // "Would you survive those three seconds? Follow for more what-ifs."
    // ==========================================
    else {
        int sf = f - 780;
        
        // Moody twilight post-disaster horizon
        CGContextSaveGState(ctx);
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGFloat twiColors[] = { 0.08, 0.04, 0.16, 1.0, 0.28, 0.15, 0.32, 1.0 };
        CGFloat twiLocs[] = { 0.0, 1.0 };
        CGGradientRef twiGrad = CGGradientCreateWithColorComponents(cs, twiColors, twiLocs, 2);
        CGContextDrawLinearGradient(ctx, twiGrad, CGPointMake(0, HEIGHT), CGPointMake(0, 0), 0);
        CGGradientRelease(twiGrad);
        CGColorSpaceRelease(cs);
        
        // Clearing starry night above
        drawStarfield(ctx, f, clamp((double)sf / 60.0, 0.0, 0.9));
        
        // Distant lightning flash (occasional dramatic flicker)
        if ((sf >= 25 && sf <= 28) || (sf >= 75 && sf <= 78)) {
            CGContextSetRGBFillColor(ctx, 0.7, 0.65, 0.95, 0.25);
            CGContextFillRect(ctx, CGRectMake(0, 0, WIDTH, HEIGHT));
            // Lightning bolt
            CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.9);
            CGContextSetLineWidth(ctx, 4.0);
            CGContextMoveToPoint(ctx, 350, 1600);
            CGContextAddLineToPoint(ctx, 380, 1400);
            CGContextAddLineToPoint(ctx, 340, 1250);
            CGContextAddLineToPoint(ctx, 390, 1050);
            CGContextStrokePath(ctx);
        }
        
        // Slow push-in zoom
        double pushZoom = 1.0 + 0.12 * easeOutCubic((double)sf / 120.0);
        CGContextTranslateCTM(ctx, WIDTH / 2.0, 480);
        CGContextScaleCTM(ctx, pushZoom, pushZoom);
        CGContextTranslateCTM(ctx, -WIDTH / 2.0, -480);
        
        // Jagged silhouette of rocky hill / rubble in foreground
        CGContextSetRGBFillColor(ctx, 0.08, 0.08, 0.10, 1.0);
        CGMutablePathRef hill = CGPathCreateMutable();
        CGPathMoveToPoint(hill, NULL, 0, 0);
        CGPathAddLineToPoint(hill, NULL, 0, 420);
        CGPathAddLineToPoint(hill, NULL, 280, 480);
        CGPathAddLineToPoint(hill, NULL, 540, 560); // peak where stickman stands!
        CGPathAddLineToPoint(hill, NULL, 780, 460);
        CGPathAddLineToPoint(hill, NULL, WIDTH, 410);
        CGPathAddLineToPoint(hill, NULL, WIDTH, 0);
        CGPathCloseSubpath(hill);
        CGContextAddPath(ctx, hill);
        CGContextFillPath(ctx);
        CGPathRelease(hill);
        
        // LONE STICKMAN SILHOUETTE STANDING HEROICALLY ATOP RUBBLE
        CGPoint heroPos = CGPointMake(540, 560);
        double capeWind = sin((double)sf * 0.18) * 0.8;
        
        drawStickman(ctx, heroPos, 2.2, 0.0,
                     -M_PI * 0.42, -M_PI * 0.35,  // arms relaxed / confident
                     -M_PI * 0.58, -M_PI * 0.65,
                     -M_PI * 0.48, -M_PI * 0.45,  // one foot slightly raised
                     -M_PI * 0.52, -M_PI * 0.55,
                     EXPR_CONFIDENT, NO, YES, capeWind, whiteCol, 6.0);
        
        CGContextRestoreGState(ctx);
        
        // BIG SUSPENSEFUL CALL TO ACTION TYPOGRAPHY:
        // Pop-in with scale
        double textScale = easeOutCubic(clamp((double)sf / 20.0, 0.0, 1.0));
        
        drawStyledText(ctx, @"WOULD YOU SURVIVE?", @"Impact", 68.0 * textScale,
                       CGPointMake(WIDTH / 2.0, 1550), yellowCol, redCol, 8.0, YES, darkBoxCol);
        
        drawStyledText(ctx, @"THOSE THREE SECONDS?", @"HelveticaNeue-Bold", 38.0 * textScale,
                       CGPointMake(WIDTH / 2.0, 1440), whiteCol, blackStrokeCol, 5.0, NO, NULL);
        
        if (sf >= 35) {
            double ctaPop = easeOutCubic(clamp((double)(sf - 35) / 20.0, 0.0, 1.0));
            drawStyledText(ctx, @"FOLLOW FOR MORE WHAT-IFS", @"HelveticaNeue-Bold", 40.0 * ctaPop,
                           CGPointMake(WIDTH / 2.0, 1260), cyanCol, blackStrokeCol, 6.0, YES, darkBoxCol);
            
            drawStyledText(ctx, @"🪐 DROP YOUR ANSWER BELOW ⬇️", @"HelveticaNeue-Bold", 30.0 * ctaPop,
                           CGPointMake(WIDTH / 2.0, 1160), whiteCol, blackStrokeCol, 4.0, NO, NULL);
        }
    }
    
    // Release colors
    CGColorRelease(whiteCol);
    CGColorRelease(yellowCol);
    CGColorRelease(redCol);
    CGColorRelease(cyanCol);
    CGColorRelease(darkBoxCol);
    CGColorRelease(redBoxCol);
    CGColorRelease(blackStrokeCol);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== Stickman Animated Video Generator Starting ===");
        
        NSString *tempVideoPath = @"/tmp/stickman_raw_video.mp4";
        NSString *audioPath = @"/tmp/full_soundtrack.m4a";
        NSString *finalOutputPath = @"/Users/danielrey/Antigrav/what_if_earth_stopped_spinning.mp4";
        
        [[NSFileManager defaultManager] removeItemAtPath:tempVideoPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:finalOutputPath error:nil];
        
        NSURL *videoURL = [NSURL fileURLWithPath:tempVideoPath];
        NSError *error = nil;
        AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:videoURL fileType:AVFileTypeMPEG4 error:&error];
        if (!writer) {
            NSLog(@"Failed to initialize AVAssetWriter: %@", error);
            return 1;
        }
        
        NSDictionary *videoSettings = @{
            AVVideoCodecKey: AVVideoCodecTypeH264,
            AVVideoWidthKey: @(WIDTH),
            AVVideoHeightKey: @(HEIGHT),
            AVVideoCompressionPropertiesKey: @{
                AVVideoAverageBitRateKey: @(9000000), // 9 Mbps high quality
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: @(FPS)
            }
        };
        
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        input.expectsMediaDataInRealTime = NO;
        
        NSDictionary *bufferAttributes = @{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
            (id)kCVPixelBufferWidthKey: @(WIDTH),
            (id)kCVPixelBufferHeightKey: @(HEIGHT),
            (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
            (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
        };
        
        AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:bufferAttributes];
        
        [writer addInput:input];
        [writer startWriting];
        [writer startSessionAtSourceTime:kCMTimeZero];
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        NSLog(@"Rendering %d frames (1080x1920 @ 30fps)...", TOTAL_FRAMES);
        
        for (int f = 0; f < TOTAL_FRAMES; f++) {
            @autoreleasepool {
                CVPixelBufferRef pixelBuffer = NULL;
                CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &pixelBuffer);
                CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
                size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
                
                CGContextRef ctx = CGBitmapContextCreate(data, WIDTH, HEIGHT, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
                
                renderFrame(ctx, f);
                
                CGContextRelease(ctx);
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                
                CMTime time = CMTimeMake(f, FPS);
                while (!input.isReadyForMoreMediaData) {
                    [NSThread sleepForTimeInterval:0.002];
                }
                [adaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
                CVPixelBufferRelease(pixelBuffer);
                
                if (f % 150 == 0 || f == TOTAL_FRAMES - 1) {
                    NSLog(@"Progress: frame %d / %d (%.1f%%)", f + 1, TOTAL_FRAMES, ((f + 1) * 100.0 / TOTAL_FRAMES));
                }
            }
        }
        
        [input markAsFinished];
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        [writer finishWritingWithCompletionHandler:^{
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        CGColorSpaceRelease(colorSpace);
        
        NSLog(@"Raw video render complete: %@", tempVideoPath);
        
        // Muxing Audio and Video with AVMutableComposition
        NSLog(@"Muxing raw video and audio soundtrack...");
        AVMutableComposition *composition = [AVMutableComposition composition];
        
        AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:tempVideoPath] options:nil];
        AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:audioPath] options:nil];
        
        AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        AVAssetTrack *audioTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        
        if (!videoTrack || !audioTrack) {
            NSLog(@"Error: Missing video or audio track! videoTrack=%@, audioTrack=%@", videoTrack, audioTrack);
            return 1;
        }
        
        CMTime duration = CMTimeMake(TOTAL_FRAMES, FPS);
        CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, duration);
        
        AVMutableCompositionTrack *compVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [compVideoTrack insertTimeRange:timeRange ofTrack:videoTrack atTime:kCMTimeZero error:nil];
        
        AVMutableCompositionTrack *compAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compAudioTrack insertTimeRange:timeRange ofTrack:audioTrack atTime:kCMTimeZero error:nil];
        
        AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
        exporter.outputURL = [NSURL fileURLWithPath:finalOutputPath];
        exporter.outputFileType = AVFileTypeMPEG4;
        
        dispatch_semaphore_t exportSema = dispatch_semaphore_create(0);
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            NSLog(@"Export completed with status: %ld (error: %@)", (long)exporter.status, exporter.error);
            dispatch_semaphore_signal(exportSema);
        }];
        dispatch_semaphore_wait(exportSema, DISPATCH_TIME_FOREVER);
        
        unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:finalOutputPath error:nil] fileSize];
        NSLog(@"SUCCESS! Final video generated at: %@ (size: %lld bytes / %.2f MB)", finalOutputPath, fileSize, fileSize / (1024.0 * 1024.0));
    }
    return 0;
}
