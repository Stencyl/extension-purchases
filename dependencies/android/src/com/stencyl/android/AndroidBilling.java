package com.stencyl.android;

import java.util.Collections;
import java.util.List;
import java.util.HashMap;
import java.util.Map;

import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;

import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.ConsumeResponseListener;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesResponseListener;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.SkuDetails;
import com.android.billingclient.api.SkuDetailsParams;
import com.stencyl.android.util.Security;

import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

public class AndroidBilling extends Extension implements
        BillingClientStateListener,
        PurchasesUpdatedListener,
        PurchasesResponseListener,
        ConsumeResponseListener
{
    private static AndroidBilling billingInstance;

    private static String publicKey = "";
    private static HaxeObject callback = null;

    private static String lastPurchaseAttempt = "";

    private BillingClient billingClient;
    private final Map<String, SkuDetails> skuDetailsMap = new HashMap<>();

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
            billingClient = BillingClient.newBuilder(mainActivity).setListener(this).build();
            billingClient.startConnection(this);
        }
    }

    @Override
    public void onBillingSetupFinished(@NonNull BillingResult billingResult) {
        if(isOk(billingResult)) {
            haxeCallback("onStarted", new Object[] { "Success" });
        } else {
            haxeCallback("onStarted", new Object[] { "Failure" });
        }
    }

    @Override
    public void onBillingServiceDisconnected() {
    }

    private interface SkuDetailsConsumer
    {
        void accept(SkuDetails details);
    }

    private void loadSkuDetails(String productID, SkuDetailsConsumer callback, Runnable errorHandler) {
        if(skuDetailsMap.containsKey(productID)) {
            callback.accept(skuDetailsMap.get(productID));
            return;
        }

        SkuDetailsParams.Builder params = SkuDetailsParams.newBuilder();
        params.setSkusList(Collections.singletonList(productID)).setType(BillingClient.SkuType.INAPP);
        billingInstance.billingClient.querySkuDetailsAsync(params.build(), (billingResult, skuDetailsList) -> {
            if(isOk(billingResult) && skuDetailsList != null) {
                for(SkuDetails details : skuDetailsList) {
                    skuDetailsMap.put(details.getSku(), details);
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

        billingInstance.loadSkuDetails(productID,
                AndroidBilling::skuLoadedForPurchase,
                AndroidBilling::failedPurchase);
    }

    private static void skuLoadedForPurchase(SkuDetails skuDetails) {
        Extension.mainActivity.runOnUiThread(() -> {
            BillingFlowParams purchaseParams =
                    BillingFlowParams.newBuilder()
                            .setSkuDetails(skuDetails)
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
                    for(String sku : purchase.getSkus()) {
                        haxeCallback("onPurchase", new Object[] {sku,purchase.getPurchaseToken()});
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
         
         billingInstance.billingClient.queryPurchasesAsync(BillingClient.SkuType.INAPP, billingInstance);
     }

    @Override
    public void onQueryPurchasesResponse(@NonNull BillingResult billingResult, @NonNull List<Purchase> list) {
        if(isOk(billingResult)) {
            for(Purchase restoredPurchase : list) {
                if(Security.verifyPurchase(publicKey, restoredPurchase.getOriginalJson(), restoredPurchase.getSignature())) {
                    for (String sku: restoredPurchase.getSkus()) {
                        haxeCallback("onRestorePurchases", new Object[] {sku, restoredPurchase.getPurchaseToken()});
                    }
                }
            }
        }
    }

    @SuppressWarnings("unused")
    public static void purchaseInfo (String sku) {
        Log.i("PurchasesInfo","ProductIDInfo: " + sku);
        
        billingInstance.loadSkuDetails(sku, skuDetails -> {
            haxeCallback("onProductsVerified", new Object[] {skuDetails.getSku(), skuDetails.getTitle(), skuDetails.getDescription(), skuDetails.getPrice()});
            Log.i("PurchasesInfo", "SKU Title : " + skuDetails.getTitle());
            Log.i("PurchasesInfo", "SKU Description : " + skuDetails.getDescription());
            Log.i("PurchasesInfo", "SKU Price : " + skuDetails.getPrice());
        }, () -> { //error handler for loading sku details
            Log.i("Purchases", "Failed to get info for " + sku);
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