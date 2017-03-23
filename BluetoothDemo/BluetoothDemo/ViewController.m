//
//  ViewController.m
//  BluetoothDemo
//
//  Created by XuanCS on 2017/3/21.
//  Copyright © 2017年 XuanCS. All rights reserved.
//

#import "ViewController.h"
#import "SVProgressHUD.h"
#import <CoreBluetooth/CoreBluetooth.h>

#ifdef DEBUG
#define NSLog(format, ...) printf("\n[%s] %s [第%d行] %s\n", __TIME__, __FUNCTION__, __LINE__, [[NSString stringWithFormat:format, ## __VA_ARGS__] UTF8String]);
#else
#define NSLog(format, ...)
#endif

#define kPeripheralName @"WooTop.Patch"    // 设备名字
#define kServiceUUID @"FFF0"             // 服务的UUID
#define kCharacteristicUUID @"FFF6"      // 特征的UUID

@interface ViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, strong) NSMutableArray *foudArray;

@property (nonatomic, strong) CBCentralManager *centralManager;

@property (nonatomic, strong) CBPeripheral *selectedPeripheral;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"蓝牙连接";
    [SVProgressHUD showWithStatus:@"连接设备中"];
    
    // 创建之后会马上检查蓝牙的状态,nil默认为主线程
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

#pragma mark - 蓝牙代理方法

// 蓝牙状态发生改变，这个方法一定要实现
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    // 蓝牙状态可用
    if (central.state == CBCentralManagerStatePoweredOn) {
        
        // 如果蓝牙支持后台模式，一定要指定服务，否则在后台断开连接不上，如果不支持，可设为nil, option里的CBCentralManagerScanOptionAllowDuplicatesKey默认为NO, 如果设置为YES,允许搜索到重名，会很耗电
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID]] options:nil];
    }
    else {
        NSLog(@"蓝牙状态异常， 请检查后重试");
    }
}


/**
 * 发现设备
 * @param peripheral 设备
 * @param advertisementData 广播内容
 * @param RSSI 信号强度
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    // 判断是否是你需要连接的设备
    if ([peripheral.name isEqualToString:kPeripheralName]) {
        peripheral.delegate = self;
        self.selectedPeripheral = peripheral;
        // 开始连接设备
        [self.centralManager connectPeripheral:self.selectedPeripheral options:nil];
    }
}


/**
 * 已经连接上设备
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    // 停止扫描
    [self.centralManager stopScan];
    // 发现服务
    [self.selectedPeripheral discoverServices:nil];
}


/**
 * 已经发现服务
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kServiceUUID]]) {
            // 根据你要的那个服务去发现特性
            [self.selectedPeripheral discoverCharacteristics:nil forService:service];
        }
        
        // 这里我是根据 180A 用来获取Mac地址，没什么实际作用，可删掉
        if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]]) {
            [self.selectedPeripheral discoverCharacteristics:nil forService:service];
        }
    }
}


/**
 * 已经发现特性
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    [SVProgressHUD showSuccessWithStatus:@"连接成功"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD dismiss];
    });
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A23"]]) {
            // 这里是读取Mac地址， 可不要， 数据固定， 用readValueForCharacteristic， 不用setNotifyValue:setNotifyValue
            [self.selectedPeripheral readValueForCharacteristic:characteristic];
        }
        
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]]) {
            // 订阅特性，当数据频繁改变时，一般用它， 不用readValueForCharacteristic
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            
            // 获取电池电量
            unsigned char send[4] = {0x5d, 0x08, 0x01, 0x3b};
            NSData *sendData = [NSData dataWithBytes:send length:4];
            
            // 这里的type类型有两种 CBCharacteristicWriteWithResponse CBCharacteristicWriteWithoutResponse，它的属性枚举可以组合
            [self.selectedPeripheral writeValue:sendData forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
            
            /*
             characteristic 属性
             typedef NS_OPTIONS(NSUInteger, CBCharacteristicProperties) {
             CBCharacteristicPropertyBroadcast												= 0x01,
             CBCharacteristicPropertyRead													= 0x02,
             CBCharacteristicPropertyWriteWithoutResponse									= 0x04,
             CBCharacteristicPropertyWrite													= 0x08,
             CBCharacteristicPropertyNotify													= 0x10,
             CBCharacteristicPropertyIndicate												= 0x20,
             CBCharacteristicPropertyAuthenticatedSignedWrites								= 0x40,
             CBCharacteristicPropertyExtendedProperties										= 0x80,
             CBCharacteristicPropertyNotifyEncryptionRequired NS_ENUM_AVAILABLE(NA, 6_0)		= 0x100,
             CBCharacteristicPropertyIndicateEncryptionRequired NS_ENUM_AVAILABLE(NA, 6_0)	= 0x200
             };
             */
            
            NSLog(@"%@",characteristic);
            // 打印结果为 <CBCharacteristic: 0x1702a2a00, UUID = FFF6, properties = 0x16, value = (null), notifying = NO>
            
            //  我的结果 为 0x16  (0x08 & 0x16)结果不成立， （0x04 & 0x16）结果成立，那写入类型就是 CBCharacteristicPropertyWriteWithoutResponse
        }
    }
}


/**
 * 数据更新的回调
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    // 这里收到的数据都是16进制，有两种转换，一种就直接转字符串，另一种是转byte数组，看用哪种方便
    
    // 直接转字符串
    NSString *orStr = characteristic.value.description;
    NSString *str = [orStr substringWithRange:NSMakeRange(1, orStr.length - 2)];
    NSString *dataStr = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSLog(@"dataStr = %@",dataStr);
    
    // 转Byte数组
    Byte *byte = (Byte *)characteristic.value.bytes;
    
    //_______________________________________________________________________________________________________________
    // 解析你的协议，附几个解协议或许能用到的函数
    
    //  unsigned long value = strtoul([subStr UTF8String], 0, 16); 把16进制的字符串，按十进制整数输出
    // [self binaryDataWithStr:str]; 十六进制的字符串转换成2进制的字符串,自己写的函数，用于复杂协议的戒子
    // [self byteWithInteger:num], 十进制转字节，用于发送命令；
}


/**
 * 设备连接断开
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    // 让它自动重连
//    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID]] options:nil];
}


/**
 * 写入成功的回调， 如果类型是CBCharacteristicWriteWithoutResponse，不会走这个方法；
 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    [self.selectedPeripheral readValueForCharacteristic:characteristic];
}


#pragma mark - 主动断开和重连连接设备

/**
 * 断开连接
 */
- (IBAction)cancelConnect:(id)sender {
    if (self.selectedPeripheral) {
        [self.centralManager cancelPeripheralConnection:self.selectedPeripheral];
    }
}

/**
 * 重新连接
 */
- (IBAction)reConnect:(id)sender {
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID]] options:nil];
}

#pragma mark - 把十六进制的字符串转换成2进制的字符串

- (NSString *)binaryDataWithStr:(NSString *)str
{
    NSMutableString *mutStr = [[NSMutableString alloc] init];
    for (NSInteger j = 0; j < str.length; j++) {
        char c = [str characterAtIndex:j];
        char cs = toupper(c);
        int a = 0;
        NSMutableArray *mutArr = [NSMutableArray array];
        if (cs >= 'A' && cs <='F') {
            a = cs - 'A' + 10;
        } else
        {
            a = cs - '0';
        }
        int n = 1;
        for(int i = 0; n != 0; i++)// 判断条件 n!=0
        {
            NSInteger m = a % 2;
            [mutArr addObject:@(m)];
            a = a / 2;
            n = a;
        }
        if (mutArr.count < 4) {
            NSInteger h = 4 - mutArr.count;
            for (int i = 0; i < h; i++) {
                [mutArr addObject:@(0)];
            }
        }
        for (int i = 0; i < 2; i++) {
            [mutArr exchangeObjectAtIndex:i withObjectAtIndex:3 - i];
        }
        for (int i = 0; i < 4; i++) {
            NSInteger dataStr  =  [mutArr[i] integerValue];
            [mutStr appendFormat:@"%ld",dataStr];
        }
    }
    return mutStr;
}

#pragma mark -  把十进制转成字节，用于发送命令；

- (Byte)byteWithInteger:(NSInteger)num
{
    Byte btye = (Byte)0xff&num;
    return btye;
}




@end
