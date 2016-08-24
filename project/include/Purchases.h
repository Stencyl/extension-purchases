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
        void requestProductInfo(const char *inProductID);
        bool validateReceipt(const char *inReceipt, const char *inPassword,bool inproductionURL);
    }
}

#endif
