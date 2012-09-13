#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h> 
#include "Purchases.h"
#include "PurchaseEvent.h"

extern "C" void send_purchase_event(PurchaseEvent &inEvent);

@interface InAppPurchase: NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>
{
    SKProduct* myProduct;
    SKProductsRequest* productsRequest;
	NSString* productID;
}

- (void)initInAppPurchase;
- (BOOL)canMakePurchases;
- (void)purchaseProduct:(NSString*)productIdentifiers;

@end

@implementation InAppPurchase

#pragma Public methods 

- (void)initInAppPurchase 
{
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (BOOL)canMakePurchases
{
    return [SKPaymentQueue canMakePayments];
} 

- (void)purchaseProduct:(NSString*)productIdentifiers
{
	productID = productIdentifiers;
	productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:productID]];
	productsRequest.delegate = self;
	[productsRequest start];
} 

#pragma mark -
#pragma mark SKProductsRequestDelegate methods 

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse*)response
{   	
	int count = [response.products count];
    
	NSLog(@"Number of Products: %i", count);
    
	if(count > 0) 
    {
		myProduct = [response.products objectAtIndex:0];
		SKPayment *payment = [SKPayment paymentWithProductIdentifier:productID];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	} 
    
    else 
    {
		NSLog(@"No products are available");
	}
    
    [productsRequest release];
}

- (void)finishTransaction:(SKPaymentTransaction*)transaction wasSuccessful:(BOOL)wasSuccessful
{
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    if(wasSuccessful)
    {
		PurchaseEvent evt(IN_APP_PURCHASE_SUCCESS);
		evt.data = [transaction.payment.productIdentifier UTF8String];
		send_purchase_event(evt);
    }
    
    else
    {
        PurchaseEvent evt(IN_APP_PURCHASE_FAIL);
		evt.data = [transaction.payment.productIdentifier UTF8String];
		send_purchase_event(evt);
    }
}

- (void)completeTransaction:(SKPaymentTransaction*)transaction
{
    [self finishTransaction:transaction wasSuccessful:YES];
} 

- (void)restoreTransaction:(SKPaymentTransaction*)transaction
{
    [self finishTransaction:transaction wasSuccessful:YES];
} 

- (void)failedTransaction:(SKPaymentTransaction*)transaction
{
    if(transaction.error.code != SKErrorPaymentCancelled)
    {
        [self finishTransaction:transaction wasSuccessful:NO];
    }
    
    else
    {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
		
		PurchaseEvent evt(IN_APP_PURCHASE_CANCEL);
		evt.data = [transaction.payment.productIdentifier UTF8String];
		send_purchase_event(evt);
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

- (void)dealloc
{
	if(myProduct) 
        [myProduct release];
    
	if(productsRequest) 
        [productsRequest release];
    
	if(productID) 
        [productID release];
    
	[super dealloc];
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
		[inAppPurchase release];
	}
}



