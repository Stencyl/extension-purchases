
package com.stencyl.android;

import java.util.Arrays;
import java.util.List;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.ImageView;
import com.stencyl.android.util.*;
import com.stencyl.android.util.IabHelper.IabAsyncInProgressException;
import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

import org.json.JSONException;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

public class AndroidBilling extends Extension
{
	private static String publicKey = "";
	private static HaxeObject callback = null;
    private static IabHelper inAppPurchaseHelper;
    
    private static String productIDInfo = "";
    private static String lastPurchaseAttempt = "";
    private static String productIDHasPurchases = "";
    
    private static boolean hasBouth = false;
	
	@Override
    public void onDestroy() {
        if (AndroidBilling.inAppPurchaseHelper != null) {
            
            try {
                AndroidBilling.inAppPurchaseHelper.dispose();
            } catch (IabAsyncInProgressException e) {
                Log.i("Purchases","Failed to dispose.");
            }
            AndroidBilling.inAppPurchaseHelper = null;
            
        }
    }
    
    public static void release()
    {
        if (AndroidBilling.inAppPurchaseHelper != null) {
            
            try {
                AndroidBilling.inAppPurchaseHelper.dispose();
            } catch (IabAsyncInProgressException e) {
                Log.i("Purchases","Failed to dispose.");
            }
            AndroidBilling.inAppPurchaseHelper = null;
            
        }
    }
    
	@Override
	 public boolean onActivityResult(int requestCode, int resultCode, Intent data) {		 
         if (inAppPurchaseHelper != null) {
             
             return !inAppPurchaseHelper.handleActivityResult (requestCode, resultCode, data);
         }
         
         return super.onActivityResult (requestCode, resultCode, data);
	 }
	

    public static void initialize (String publicKey, HaxeObject callback) {
        
        Log.i ("Purchases", "Initializing billing service");
        
        AndroidBilling.publicKey = publicKey;
        AndroidBilling.callback = callback;
        
        if (AndroidBilling.inAppPurchaseHelper != null) {
            
            try {
                AndroidBilling.inAppPurchaseHelper.dispose();
            } catch (IabAsyncInProgressException e) {
                Log.i("Purchases","Failed to dispose.");
            }
            
        }
        
        AndroidBilling.inAppPurchaseHelper = new IabHelper (Extension.mainContext, publicKey);
        AndroidBilling.inAppPurchaseHelper.startSetup (new IabHelper.OnIabSetupFinishedListener () {
            
            public void onIabSetupFinished (final IabResult result) {
                
                if (result.isSuccess ()) {
                    
                    Extension.callbackHandler.post (new Runnable () {
                        
                        @Override public void run () {
                            
                            AndroidBilling.callback.call ("onStarted", new Object[] { "Success" });
                            
                        }
                        
                    });
                    
                } else {
                    Extension.callbackHandler.post (new Runnable () {
                        
                        @Override public void run () {
                            
                            AndroidBilling.callback.call ("onStarted", new Object[] { "Failure" });
                            
                        }
                        
                    });
                }
                
            }
            
        });
        
    }
    
    public static void buy (final String productID) {
        
        lastPurchaseAttempt = productID;
        // IabHelper.launchPurchaseFlow() must be called from the main activity's UI thread
        Extension.mainActivity.runOnUiThread(new Runnable() {
            public void run() {
            	if (inAppPurchaseHelper != null) inAppPurchaseHelper.flagEndAsync();
                try {
                    AndroidBilling.inAppPurchaseHelper.launchPurchaseFlow (Extension.mainActivity, productID, 1001, mPurchaseFinishedListener);
                } catch (IabAsyncInProgressException e) {
                    Log.e("Purchases", "Failed to launch purchase flow.", e);
                    mPurchaseFinishedListener.onIabPurchaseFinished(
                                                                    new IabResult(IabHelper.BILLING_RESPONSE_RESULT_ERROR, null),
                                                                    null);
                }
            }
        });
    }

    public static void consume(final String purchaseJson, final String itemType, final String signature)
	 {
         Log.i("Purchases","Consume start purchaseJson: " + purchaseJson);
         Log.i("Purchases","Consume start itemType: " + itemType);
         Log.i("Purchases","Consume start signature: " + signature);

         Extension.mainActivity.runOnUiThread (new Runnable ()
                                         {
             @Override public void run ()
             {
            	 if (inAppPurchaseHelper != null) inAppPurchaseHelper.flagEndAsync();
                 
                 try {
                     final Purchase purchase = new Purchase(itemType, purchaseJson, signature);
                     try {
                         AndroidBilling.inAppPurchaseHelper.consumeAsync(purchase, mConsumeFinishedListener);
                     } catch (IabAsyncInProgressException e) {
                         Log.i("Purchases","Error consuming. Another async operation in progress.");
                     }
                 }
                 
                 catch (JSONException e)
                 {
                     // This is not a normal consume failure, just a Json parsing error
                     
                     Extension.mainActivity.runOnUiThread (new Runnable ()
                                                     {
                         @Override public void run ()
                         {
                             String resultJson = "{\"response\": -999, \"message\":\"Json Parse Error \"}";
                             
                             Log.i ("Purchases","Consume Failed: " + resultJson);
                            
                         }
                     });
                     
                 } // catch
             } // run
         });
	 }
	 
	 public static void restore()
	 {
         Log.i("Purchases", "Attempt to Restore Purchases");
         
         Extension.mainActivity.runOnUiThread(new Runnable() {
             public void run() {
                 try {
                     AndroidBilling.inAppPurchaseHelper.queryInventoryAsync(mGotInventoryListenerForRestore);
                 } catch(Exception e) {
                     Log.d("Purchases", e.getMessage());
                 }
             }
         });

	 }
    
    public static void purchaseInfo (String moreSkusArr) {
    	
    	productIDInfo = moreSkusArr;
    	Log.i("PurchasesInfo","ProductIDInfo: " + productIDInfo);
    	
    	ArrayList<String> skuList = new ArrayList<String> ();
        skuList.add(moreSkusArr);
        final List<String> moreSkus = new ArrayList(skuList);
        
        Log.i("Purchase", "purchaseInfo id's " + moreSkusArr);

        final boolean querySkuDetails = true;
        
        Extension.mainActivity.runOnUiThread(new Runnable() {
            public void run() {
                try {
                    AndroidBilling.inAppPurchaseHelper.queryInventoryAsync(querySkuDetails, moreSkus, null, mGotInventoryListenerForInfo);
                } catch(Exception e) {
                    Log.d("Purchases", e.getMessage());
                }
            }
        });
    }

	 public static void setPublicKey(String s)
	 {		
		 publicKey = s;
	 }

	 public static String getPublicKey()
	 {
		 return publicKey;
	 }
    
    ////////////////////Listeners///////////
    static IabHelper.OnIabPurchaseFinishedListener mPurchaseFinishedListener = new IabHelper.OnIabPurchaseFinishedListener () {
    
        public void onIabPurchaseFinished (final IabResult result, final Purchase purchase)
        {
    
            if (result.isFailure())
            {
            Log.i("Purchase", "Failed to buy " + result);
				
            Extension.callbackHandler.post (new Runnable ()
            {
                @Override public void run ()
                {
                    
                    if (result.getResponse() == IabHelper.IABHELPER_USER_CANCELLED) {
                        AndroidBilling.callback.call ("onCanceledPurchase", new Object[] {lastPurchaseAttempt});
                    } else {
                        
                        if(lastPurchaseAttempt.equals("android.test.purchased")){
                            
                            if(purchase == null){
                                AndroidBilling.callback.call ("onFailedPurchase", new Object[] {lastPurchaseAttempt});
                                
                            }else{
                                
                                AndroidBilling.callback.call ("onPurchase", new Object[] {purchase.getSku(),purchase.getOriginalJson(), purchase.getItemType(), "android.test.purchased"});
                            
                                Log.i("PurchasesBuy", "SKU : " + purchase.getSku());
                                Log.i("PurchasesBuy", "OrgJson : " + purchase.getOriginalJson());
                                Log.i("PurchasesBuy", "ItemType : " + purchase.getItemType());
                                Log.i("PurchasesBuy", "Signature : " + purchase.getSignature());
                            }
                        
                        }else{
                            AndroidBilling.callback.call ("onFailedPurchase", new Object[] {lastPurchaseAttempt});
                        }
                    }
                }
            });
				
            }
            else
            {
                Extension.callbackHandler.post (new Runnable ()
                {
                    @Override public void run ()
                    {
                        // AndroidBilling.callback.call ("onPurchase", new Object[] { purchase.getOriginalJson(), purchase.getSignature(), purchase.getItemType() });
                        Log.i("Purchase", "got purchase response: " + purchase.getOriginalJson());
                    
                        AndroidBilling.callback.call ("onPurchase", new Object[] {purchase.getSku(),purchase.getOriginalJson(), purchase.getItemType(), purchase.getSignature()});

                        Log.i("PurchasesBuy", "SKU : " + purchase.getSku());
                        Log.i("PurchasesBuy", "OrgJson : " + purchase.getOriginalJson());
                        Log.i("PurchasesBuy", "ItemType : " + purchase.getItemType());
                        Log.i("PurchasesBuy", "Signature : " + purchase.getSignature());
                    }
                });
            }

        }

    };

    static IabHelper.OnConsumeFinishedListener mConsumeFinishedListener = new IabHelper.OnConsumeFinishedListener () {

        public void onConsumeFinished (final Purchase purchase, final IabResult result) {

        if (result.isFailure ())
        {

            Extension.callbackHandler.post (new Runnable ()
            {
                @Override public void run ()
                {
                    Log.i ("Purchases", "Failed to consume");
                    //AndroidBilling.callback.call ("onFailedConsume", new Object[] { ("{\"result\":" + result.toJsonString() + ", \"product\":" + purchase.       getOriginalJson() + "}") });
                }
            });
        }
        else
        {
            Extension.callbackHandler.post (new Runnable ()
            {
                @Override public void run ()
                {
                Log.i ("Purchases", "Succesfully consume");
                //AndroidBilling.callback.call ("onConsume", new Object[] { purchase.getOriginalJson() });
                }
            });
        }

    }

    };

    static IabHelper.QueryInventoryFinishedListener mGotInventoryListenerForRestore = new IabHelper.QueryInventoryFinishedListener() {

        public void onQueryInventoryFinished(final IabResult result, final Inventory inventory) {
            if (result.isFailure()) {
            // handle error here
                Extension.callbackHandler.post (new Runnable ()
                {
                    @Override public void run ()
                    {
                        Log.i("Purchases", "Failed to restore " + result);
                        //return;

                    }
                });
            }
            else
            {
                Extension.callbackHandler.post (new Runnable ()
                {
                    @Override public void run ()
                    {
                        Purchase restorePurchase = null;

                        final List<String> allOwnedSkus = inventory.getAllOwnedSkus();

                        if (allOwnedSkus.size() == 0)
                        {
                            Log.i("PurchasesRestore", "Failed to restore, No Managed Products Owned");
                        }else{
                            for (String sku: allOwnedSkus)
                            {
                                restorePurchase = inventory.getPurchase(sku);

                                AndroidBilling.callback.call("onRestorePurchases", new Object[] {restorePurchase.getSku(), restorePurchase.getOriginalJson(), restorePurchase.getItemType(), restorePurchase.getSignature()});

                                Log.i("PurchasesRestore", "SKU : " + restorePurchase.getSku());
                                Log.i("PurchasesRestore", "OrgJson : " + restorePurchase.getOriginalJson());
                                Log.i("PurchasesRestore", "ItemType : " + restorePurchase.getItemType());
                                Log.i("PurchasesRestore", "Signature : " + restorePurchase.getSignature());
                            }
                        }
                    }
                });
            }
        }

    };

    static IabHelper.QueryInventoryFinishedListener mGotInventoryListenerForInfo = new IabHelper.QueryInventoryFinishedListener() {

        public void onQueryInventoryFinished(final IabResult result, final Inventory inventory) {

            final String SKU = productIDInfo;

            if (result.isFailure()) {
                // handle error here
                Extension.callbackHandler.post (new Runnable ()
                {
                    @Override public void run ()
                    {

                        Log.i("Purchases", "Failed to get Info " + result);
                        //return;
                    }
                });
            }
            else {

                Extension.callbackHandler.post (new Runnable ()
                {
                    @Override public void run ()
                    {

                        if(inventory.getSkuDetails(SKU) != null){

                            AndroidBilling.callback.call("onProductsVerified", new Object[] {inventory.getSkuDetails(SKU).getSku(), inventory.getSkuDetails(SKU).getTitle(), inventory.getSkuDetails(SKU).getDescription(), inventory.getSkuDetails(SKU).getPrice()});
                                Log.i("PurchasesInfo", "SKU Title : " + inventory.getSkuDetails(SKU).getTitle());
                                Log.i("PurchasesInfo", "SKU Descruption : " + inventory.getSkuDetails(SKU).getDescription());
                                Log.i("PurchasesInfo", "SKU Price : " + inventory.getSkuDetails(SKU).getPrice());

                        }else{
                            Log.i("Purchases", "SKU RETURNED NULL " + SKU);
                        }


                    }
                });
            }
        }

    };

}