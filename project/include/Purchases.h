#ifndef Purchases
#define Purchases

namespace purchases 
{	
    extern "C"
    {	
        void initInAppPurchase();
        void restorePurchases();
        bool canPurchase();
        void purchaseProduct(const char* productID);
        void releaseInAppPurchase();
    }
}

#endif
