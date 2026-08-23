//
//  LookinCustomDisplayItemInfo+LookinClient.h
//  LookinClient
//
//  Created by likai.123 on 2023/11/1.
//  Copyright © 2023 hughkli. All rights reserved.
//

#import "LookinCustomDisplayItemInfo.h"

NS_ASSUME_NONNULL_BEGIN

// hasValidFrame moved into LookinCore's LookinCustomDisplayItemInfo so it can
// be unit-tested and shared with the server side. The category stays (empty)
// only because removing the files would require project-file surgery; a
// category re-declaring the method would override the class implementation.
@interface LookinCustomDisplayItemInfo (LookinClient)

@end

NS_ASSUME_NONNULL_END
