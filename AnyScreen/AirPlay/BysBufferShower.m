//
//  BysBufferShower.m
//  AnyScreen
//
//  Created by hanJianXin on 16/8/2.
//  Copyright © 2016年 xindawn. All rights reserved.
//

#import "BysBufferShower.h"

@implementation BysBufferShower

void showbuffer( uint8_t * buffer, int buflen){
    NSString *str = [[NSString alloc] init];
    str = @"\n\n\n------- >>  buffer内容：\n";
    uint8_t *p = buffer;
    for (int i=0; i<buflen; i++) {
        uint8_t ch = *p++;
        if (i%16==0) {
            str = [str stringByAppendingString:@"\n"];
        }
        str = [str stringByAppendingString:[NSString stringWithFormat:@"  %02x",ch]];
    }
    NSLog(@"%@\n\n",str);
}

@end
