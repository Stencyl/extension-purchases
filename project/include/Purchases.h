#ifndef Purchases
#define Purchases

namespace purchases 
{	
    extern "C"
    {	
        void initInAppPurchase();
        bool canPurchase();
        void purchaseProduct(const char* productID);
        void releaseInAppPurchase();
    }
}

#endif
