#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h> 
#import <Foundation/Foundation.h>
#include <Availability.h>
#include "Purchases.h"
#include "PurchaseEvent.h"

extern "C" void sendPurchaseEvent(const char* type, const char* data);
extern "C" void sendPurchaseFinishEvent(const char* type, const char* data, const char* receiptString, const char* transactionID);
extern "C" void sendPurchaseEventForeign(const char* type, const char* data);
extern "C" void sendPurchaseFinishEventForeign(const char* type, const char* data, const char* receiptString, const char* transactionID);

#define IOS_13  ([[[UIDevice currentDevice] systemVersion] compare:@"13.0" options:NSNumericSearch] != NSOrderedAscending)
#define spe(type, data)  if(IOS_13) sendPurchaseEventForeign(type, data); else sendPurchaseEvent(type, data);
#define spfe(type, data, receipt, transaction) if(IOS_13) sendPurchaseFinishEventForeign(type, data, receipt, transaction); else sendPurchaseFinishEvent(type, data, receipt, transaction);

@interface InAppPurchase: NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>
{
    SKProductsRequest* productsRequest;
    NSMutableDictionary* authorizedProducts;
    BOOL arePurchasesEnabled;
    BOOL prodURL;
    BOOL validatedSucceed;
}

@property (nonatomic, assign) BOOL arePurchasesEnabled;
@property (nonatomic, assign) BOOL prodURL;
@property (nonatomic, assign) BOOL validatedSucceed;

- (void)initInAppPurchase;
- (void)restorePurchases;
- (BOOL)canMakePurchases;
- (void)purchaseProduct:(NSString*)productId;
- (void)requestProductInfo:(NSMutableSet*)productIdentifiers;
- (const char*)getProductTitle:(NSString*)productId;
- (const char*)getProductDescription:(NSString*)productId;
- (const char*)getProductPrice:(NSString*)productId;
- (void)checkReceipt:(NSString*)receiptString withSHARED_SECRET:(NSString*)SHARED_SECRET;

@end

@implementation InAppPurchase

@synthesize arePurchasesEnabled;
@synthesize prodURL;
@synthesize validatedSucceed;

#pragma mark - Public methods

- (void)initInAppPurchase
{
    NSLog(@"Purchases initialize");
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    spe("started", "");
    productsRequest = nil;
    authorizedProducts = [[NSMutableDictionary alloc] init];
    arePurchasesEnabled = NO;
}

- (void)restorePurchases
{
    NSLog(@"starting restore");
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (BOOL)canMakePurchases
{
    return (arePurchasesEnabled && [SKPaymentQueue canMakePayments]);
}

- (void)purchaseProduct:(NSString*)productId
{
    if(!arePurchasesEnabled || ![SKPaymentQueue canMakePayments])
    {
        spe("failed", [productId UTF8String]);
        return;
    }
    
    SKProduct *skProduct = [authorizedProducts objectForKey:productId];
    if(skProduct)
    {
        SKPayment *payment = [SKPayment paymentWithProduct:skProduct];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        return;
    }
    
    spe("failed", [productId UTF8String]);
}

// Multiple requests can be made, they'll be added into authorized list if not already there.
- (void)requestProductInfo:(NSMutableSet*)productIdentifiers
{
    arePurchasesEnabled = NO;
    
    productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    productsRequest.delegate = self;
    [productsRequest start];
}
    
- (const char*)getProductTitle:(NSString*)productId
    {
        SKProduct *skProduct = [authorizedProducts objectForKey:productId];
        if(skProduct)
        {
            if(skProduct.localizedTitle != nil) // nil will crash app
            {
                return [skProduct.localizedTitle cStringUsingEncoding:NSUTF8StringEncoding];
            }
        }
        
        return "None";
    }
    
- (const char*)getProductDescription:(NSString*)productId
    {
        SKProduct *skProduct = [authorizedProducts objectForKey:productId];
        if(skProduct)
        {
            if(skProduct.localizedDescription != nil) // nil will crash app
            {
                return [skProduct.localizedDescription cStringUsingEncoding:NSUTF8StringEncoding];
            }
        }
        
        return "None";
    }
    
- (const char*)getProductPrice:(NSString*)productId
    {
        SKProduct *skProduct = [authorizedProducts objectForKey:productId];
        if(skProduct)
        {
            NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
            [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
            [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
            [numberFormatter setLocale:skProduct.priceLocale];
            NSString *formattedString = [numberFormatter stringFromNumber:skProduct.price];
            
            // Replace Euro UTF-16 with pseudo Unicode if it's in there.
            NSString *euroSymbol = [NSString stringWithFormat:@"%C", 0x20AC]; // UTF-16
            NSString *euroPseudo = @"~x20AC"; // Stencyl's pseudo Unicode ~x
            formattedString = [formattedString stringByReplacingOccurrencesOfString:euroSymbol withString:euroPseudo];
            
            return [formattedString cStringUsingEncoding:NSUTF8StringEncoding];
        }
        
        return "None";
    }
    
-(void)checkReceipt:(NSString*)receiptString withSHARED_SECRET:(NSString*)SHARED_SECRET{
    // verifies receipt with Apple
    
    if(!receiptString){
        validatedSucceed = NO;
        return;
    }
    
    NSError *jsonError = nil;
    
    NSString *receiptBase64 = receiptString;
    //NSLog(@"Receipt Base64: %@",receiptBase64);
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                receiptBase64,@"receipt-data",
                                                                SHARED_SECRET,@"password",
                                                                nil]
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&jsonError
                        ];
    //NSLog(@"%@",jsonData);
    NSError * error=nil;
    NSDictionary * parsedData = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
    //NSLog(@"%@",parsedData);
    //NSLog(@"JSON: %@",[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    
    // URL for sandbox receipt validation; replace "sandbox" with "buy" in production or you will receive
    // error codes 21006 or 21007
    
    NSURL *requestURL;
    if(prodURL){
       requestURL = [NSURL URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"];
    }else{
       requestURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    }
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:requestURL];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:jsonData];
    
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:req queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                    NSLog(@"Connection Error : %@",connectionError);
                                   
                                   /* ... Handle error ... */
                                   validatedSucceed = NO;
                               } else {
                                   NSError *error;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                   //NSLog(@"Respond : %@",jsonResponse);
                                   if (!jsonResponse) {
                                       /* ... Handle error ...*/
                                       NSLog(@"No response");
                                       validatedSucceed = NO;
                                       
                                   }
                                   
                                   NSString *status = [jsonResponse objectForKey:@"status"];
                                   
                                   NSNumber *myNumber = [jsonResponse objectForKey:@"status"];
                                   int value = abs(myNumber.intValue);
                                   
                                   
                                   NSLog(@"Receipt Status %@", status);
                                   
                                   if (value == 0) {
                                       
                                       NSLog(@"Joehoe you Receipt is valid");
                                       
                                       validatedSucceed = YES;
                                           
                                   }else{
                                       
                                       NSLog(@"Faild to validate Status: %@", status);
                                       validatedSucceed = NO;
                                   }
                                   
                               }
                           }];
    
}

#pragma mark - SKProductsRequestDelegate methods

- (void)request:(SKProductsRequest *)request didFailWithError:(NSError *)error
{
    productsRequest = nil;
    arePurchasesEnabled = NO;
}

- (void)productsRequest:(SKProductsRequest*)request didReceiveResponse:(SKProductsResponse*)response
{
    NSArray *skProducts = response.products;
    for (SKProduct *skProduct in skProducts)
    { // Add requested products, replacing duplicates that are already in there.
        [authorizedProducts setObject:skProduct forKey:[skProduct productIdentifier]];
    }
    
    productsRequest = nil;
    arePurchasesEnabled = YES;
    spe("productsVerified", "");
}

#pragma mark - SKPaymentTransactionObserver and Purchase helper methods

- (void)finishTransaction:(SKPaymentTransaction*)transaction wasSuccessful:(BOOL)wasSuccessful
{
	if(wasSuccessful)
	{
        
        NSLog(@"Transaction finished successful");
        
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
        NSString *jsonObjectString = [receipt base64EncodedStringWithOptions:0];
        
        if(!receipt){
            return;
        }
        
        spfe("success", [transaction.payment.productIdentifier UTF8String],[jsonObjectString UTF8String],[transaction.transactionIdentifier UTF8String]);
	}

	else
	{
        NSLog(@"Failed Purchase");
        if (transaction.error.code != SKErrorPaymentCancelled)
        {
            NSLog(@"Transaction error: %@", transaction.error.localizedDescription);
        }
        spe("failed", [transaction.payment.productIdentifier UTF8String]);
	}
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)completeTransaction:(SKPaymentTransaction*)transaction
{
    NSLog(@"Finish Transaction");
	[self finishTransaction:transaction wasSuccessful:YES];
}

- (void)restoreTransaction:(SKPaymentTransaction*)transaction
{
    NSLog(@"Transaction finished successful");
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    NSString *jsonObjectString = [receipt base64EncodedStringWithOptions:0];
    
    if(!receipt){
        return;
    }
    
    spfe("restore", [transaction.payment.productIdentifier UTF8String],[jsonObjectString UTF8String],[transaction.transactionIdentifier UTF8String]);
    
    //sendPurchaseEvent("restore", [transaction.originalTransaction.payment.productIdentifier UTF8String]);
    //[self finishTransaction:transaction wasSuccessful:YES];
}

- (void)failedTransaction:(SKPaymentTransaction*)transaction
{
	if(transaction.error.code != SKErrorPaymentCancelled)
	{
		switch (transaction.error.code)
		{
			case SKErrorUnknown:
				NSLog(@"SKErrorUnknown Transaction error: %@", transaction.error.localizedDescription);
			break;
			case SKErrorClientInvalid:
				NSLog(@"SKErrorClientInvalid Transaction error: %@", transaction.error.localizedDescription);
			break;
			case SKErrorPaymentInvalid:
				NSLog(@"SKErrorPaymentInvalid Transaction error: %@", transaction.error.localizedDescription);
			break;
			case SKErrorPaymentNotAllowed:
				NSLog(@"SKErrorPaymentNotAllowed Transaction error: %@", transaction.error.localizedDescription);
			break;
			default:
				NSLog(@"Transaction error: %@", transaction.error.localizedDescription);
			break;
		}

		[self finishTransaction:transaction wasSuccessful:NO];
	}

	else
	{
		spe("cancel", [transaction.payment.productIdentifier UTF8String]);
		[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
	}
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray*)transactions
{
	for(SKPaymentTransaction *transaction in transactions)
	{
		switch(transaction.transactionState)
		{
			case SKPaymentTransactionStatePurchased:
				[self completeTransaction:transaction];
				break;

			case SKPaymentTransactionStateFailed:
				[self failedTransaction:transaction];
				break;

			case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
			break;

			default:
				break;
		}
	}
}


#pragma mark - More Public methods

- (void)dealloc
{
    if(authorizedProducts)
        authorizedProducts = nil;
    
    if(productsRequest)
        productsRequest = nil;
}

@end

extern "C"
{
	static InAppPurchase* inAppPurchase = nil;
    
	void initInAppPurchase()
	{
		inAppPurchase = [[InAppPurchase alloc] init];
		[inAppPurchase initInAppPurchase];
	}

	void restorePurchases() 
	{
		[inAppPurchase restorePurchases];
	}

	bool canPurchase()
	{
		return [inAppPurchase canMakePurchases];
	}

	void purchaseProduct(const char *inProductID)
	{
		NSString *productID = [[NSString alloc] initWithUTF8String:inProductID];
		[inAppPurchase purchaseProduct:productID];
	}

	void releaseInAppPurchase()
	{
		inAppPurchase = nil;
	}

    void requestProductInfo(const char *inProductIDcommalist)
    {
        NSString *productIDs = [[NSString alloc] initWithUTF8String:inProductIDcommalist];
        NSMutableSet *productIdentifiers = [NSMutableSet setWithArray:[productIDs componentsSeparatedByString:@","]];
        [inAppPurchase requestProductInfo:productIdentifiers];
    }
    
    const char* getTitle(const char *inProductID)
    {
        NSString *productID = [[NSString alloc] initWithUTF8String:inProductID];
        return [inAppPurchase getProductTitle:productID];
    }
    
    const char* getPrice(const char *inProductID)
    {
        NSString *productID = [[NSString alloc] initWithUTF8String:inProductID];
        return [inAppPurchase getProductPrice:productID];
    }
    
    const char* getDescription(const char *inProductID)
    {
        NSString *productID = [[NSString alloc] initWithUTF8String:inProductID];
        return [inAppPurchase getProductDescription:productID];
    }
    
    bool validateReceipt(const char *inReceipt, const char *inPassword,bool inproductionURL)
    {
        NSString *receipt = [[NSString alloc] initWithUTF8String:inReceipt];
        NSString *pass = [[NSString alloc] initWithUTF8String:inPassword];
        
        
        if(inproductionURL){
            
            inAppPurchase.prodURL = YES;
            
        }else{
            
            inAppPurchase.prodURL = NO;
        }
        
        [inAppPurchase checkReceipt:receipt withSHARED_SECRET:pass];
        
        return inAppPurchase.validatedSucceed;
        
    }
}
