package com.stencyl.android;

import java.util.Collections;
import java.util.List;
import java.util.HashMap;
import java.util.Map;

import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.AcknowledgePurchaseResponseListener;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.ConsumeResponseListener;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchaseHistoryRecord;
import com.android.billingclient.api.PurchaseHistoryResponseListener;
import com.android.billingclient.api.PurchasesResponseListener;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchaseHistoryParams;
import com.android.billingclient.api.QueryPurchasesParams;
import com.stencyl.android.util.Security;

import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

public class AndroidBilling extends Extension implements
        BillingClientStateListener,
        PurchasesUpdatedListener,
        PurchasesResponseListener,
        PurchaseHistoryResponseListener,
        AcknowledgePurchaseResponseListener,
        ConsumeResponseListener
{
    private static AndroidBilling billingInstance;

    private static String publicKey = "";
    private static HaxeObject callback = null;

    private static boolean readPurchasesCache = false;
    private static String lastPurchaseAttempt = "";

    private BillingClient billingClient;
    private final Map<String, ProductDetails> productDetailsMap = new HashMap<>();

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        billingInstance = this;
    }

    @Override
    public void onDestroy() {
        if(billingInstance != null) {
            billingInstance.dispose();
            billingInstance = null;
        }
    }

    private void dispose() {
        if(billingClient != null)
        {
            billingClient.endConnection();
            billingClient = null;
        }
    }
    
    public static void release() {
        if(billingInstance != null) {
            billingInstance.dispose();
            billingInstance = null;
        }
    }

    @SuppressWarnings("unused")
    public static void initialize (String publicKey, HaxeObject callback) {
        
        Log.i ("Purchases", "Initializing billing service");

        AndroidBilling.publicKey = publicKey;
        AndroidBilling.callback = callback;

        billingInstance.initialize();
    }

    public void initialize() {
        if(billingClient == null || billingClient.getConnectionState() == BillingClient.ConnectionState.CLOSED) {
            billingClient = BillingClient.newBuilder(mainActivity)
                    .setListener(this)
                    .enablePendingPurchases()
                    .build();
            billingClient.startConnection(this);
        }
    }

    @Override
    public void onBillingSetupFinished(@NonNull BillingResult billingResult) {
        if(isOk(billingResult)) {
            billingInstance.billingClient.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
                billingInstance);
            haxeCallback("onStarted", new Object[] { "Success" });
        } else {
            haxeCallback("onStarted", new Object[] { "Failure" });
        }
    }

    @Override
    public void onQueryPurchasesResponse(@NonNull BillingResult billingResult, @NonNull List<Purchase> list) {
        boolean isInit = !readPurchasesCache;
        readPurchasesCache = true;
        
        if(isOk(billingResult)) {
            for(Purchase restoredPurchase : list) {
                if(Security.verifyPurchase(publicKey, restoredPurchase.getOriginalJson(), restoredPurchase.getSignature())) {
                    for (String product: restoredPurchase.getProducts()) {
                        haxeCallback("onRestorePurchases", new Object[] {
                                product,
                                restoredPurchase.getPurchaseToken(),
                                restoredPurchase.getPurchaseState(),
                                restoredPurchase.isAcknowledged(),
                                isInit});
                    }
                }
            }
        }
    }

    @Override
    public void onBillingServiceDisconnected() {
    }

    private interface ProductDetailsConsumer
    {
        void accept(ProductDetails details);
    }

    private void loadProductDetails(String productID, ProductDetailsConsumer callback, Runnable errorHandler) {
        if(productDetailsMap.containsKey(productID)) {
            callback.accept(productDetailsMap.get(productID));
            return;
        }

        QueryProductDetailsParams.Builder params = QueryProductDetailsParams.newBuilder();
        params.setProductList(Collections.singletonList(
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(productID)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()));
        billingInstance.billingClient.queryProductDetailsAsync(params.build(), (billingResult, productDetailsList) -> {
            if(isOk(billingResult)) {
                for(ProductDetails details : productDetailsList) {
                    productDetailsMap.put(details.getProductId(), details);
                    callback.accept(details);
                }
            }
            else {
                errorHandler.run();
            }
        });
    }

    @SuppressWarnings("unused")
    public static void buy (final String productID) {
        lastPurchaseAttempt = productID;

        billingInstance.loadProductDetails(productID,
                AndroidBilling::productLoadedForPurchase,
                AndroidBilling::failedPurchase);
    }

    private static void productLoadedForPurchase(ProductDetails productDetails) {

        Extension.mainActivity.runOnUiThread(() -> {

            BillingFlowParams purchaseParams =
                    BillingFlowParams.newBuilder()
                        .setProductDetailsParamsList(Collections.singletonList(
                            BillingFlowParams.ProductDetailsParams.newBuilder()
                                .setProductDetails(productDetails)
                                .build())
                        )
                        .build();

            billingInstance.billingClient.launchBillingFlow(mainActivity, purchaseParams);
        });
    }

    private static void canceledPurchase() {
        haxeCallback("onCanceledPurchase", new Object[] {lastPurchaseAttempt});
        lastPurchaseAttempt = null;
    }

    private static void failedPurchase() {
        haxeCallback("onFailedPurchase", new Object[] {lastPurchaseAttempt});
        lastPurchaseAttempt = null;
    }

    @Override
    public void onPurchasesUpdated(@NonNull BillingResult billingResult, List<Purchase> list) {
        if(isOk(billingResult)) {
            for(Purchase purchase : list) {
                if(Security.verifyPurchase(publicKey, purchase.getOriginalJson(), purchase.getSignature())) {
                    for(String productId : purchase.getProducts()) {
                        haxeCallback("onPurchase", new Object[] {
                                productId,
                                purchase.getPurchaseToken(),
                                purchase.getPurchaseState(),
                                purchase.isAcknowledged()});
                    }
                } else {
                    failedPurchase();
                }
            }
        } else if(billingResult.getResponseCode() == BillingClient.BillingResponseCode.USER_CANCELED) {
            canceledPurchase();
        } else {
            failedPurchase();
        }
    }

    @SuppressWarnings("unused")
    public static void acknowledge(final String purchaseToken)
    {
        AcknowledgePurchaseParams acknowledgeParams =
                AcknowledgePurchaseParams.newBuilder()
                        .setPurchaseToken(purchaseToken)
                        .build();

        billingInstance.billingClient.acknowledgePurchase(acknowledgeParams, billingInstance);
    }

    @Override
    public void onAcknowledgePurchaseResponse(@NonNull BillingResult billingResult) {
        if(isOk(billingResult)) {
            Log.i ("Purchases", "Successfully acknowledge");
        } else {
            Log.i ("Purchases", "Failed to acknowledge");
        }
    }

    @SuppressWarnings("unused")
    public static void consume(final String purchaseToken)
     {
         ConsumeParams consumeParams =
                 ConsumeParams.newBuilder()
                         .setPurchaseToken(purchaseToken)
                         .build();

         billingInstance.billingClient.consumeAsync(consumeParams, billingInstance);
     }

    @Override
    public void onConsumeResponse(@NonNull BillingResult billingResult, @NonNull String s) {
        if(isOk(billingResult)) {
            Log.i ("Purchases", "Successfully consume");
        } else {
            Log.i ("Purchases", "Failed to consume");
        }
    }

    @SuppressWarnings("unused")
    public static void restore() {
         Log.i("Purchases", "Attempt to Restore Purchases");


         billingInstance.billingClient.queryPurchaseHistoryAsync(
             QueryPurchaseHistoryParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
             billingInstance);
     }

    @Override
    public void onPurchaseHistoryResponse(@NonNull BillingResult billingResult, @Nullable List<PurchaseHistoryRecord> list) {
        if(isOk(billingResult)) {
            billingInstance.billingClient.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
                billingInstance);
        }
    }

    @SuppressWarnings("unused")
    public static void purchaseInfo (String productId) {
        Log.i("PurchasesInfo","ProductIDInfo: " + productId);
        
        billingInstance.loadProductDetails(productId, productDetails -> {
            haxeCallback("onProductsVerified", new Object[] {
                productDetails.getProductId(),
                productDetails.getTitle(),
                productDetails.getDescription(),
                productDetails.getOneTimePurchaseOfferDetails().getFormattedPrice()});
            Log.i("PurchasesInfo", "Product Title : " + productDetails.getTitle());
            Log.i("PurchasesInfo", "Product Description : " + productDetails.getDescription());
            Log.i("PurchasesInfo", "Product Price : " + productDetails.getOneTimePurchaseOfferDetails().getFormattedPrice());
        }, () -> { //error handler for loading product details
            Log.i("Purchases", "Failed to get info for " + productId);
        });
    }

    private boolean isOk(BillingResult billingResult) {
        if(billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
            return true;
        } else {
            if(billingResult.getResponseCode() == BillingClient.BillingResponseCode.SERVICE_DISCONNECTED) {
                initialize();
            }
            Log.i("Purchases", "[Error] " + billingResult.getDebugMessage());
            return false;
        }
    }

    private static void haxeCallback(String function, Object[] args) {
        Extension.callbackHandler.post (() -> AndroidBilling.callback.call (function, args));
    }
}