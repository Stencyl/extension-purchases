
import com.anjlab.android.iab.v3.*;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.ImageView;
import org.haxe.nme.GameActivity;
import org.haxe.nme.HaxeObject;

import org.haxe.extension.Extension;

public class AndroidBilling extends Extension implements BillingProcessor.IBillingHandler
{
	private static String publicKey = "";
	private static HaxeObject callback = null;
	private static AndroidBilling ab;
	private static BillingProcessor bp;
	
	private static String lastPurchaseAttempt = "";

	public AndroidBilling()
    {
    	super();
    	
    	ab = this;
    }
	
    public static void release() {
        if (bp != null) 
        {
            bp.release();
            bp = null;
        }
    }

	public static void initialize(String publicKey, final HaxeObject callback)
	{
		Log.i("IAP", "Attempt to init billing service");
	
		ab = new AndroidBilling();
		AndroidBilling.callback = callback;
		setPublicKey(publicKey);
		
		bp = new BillingProcessor(mainActivity, publicKey, ab);
	}
	
	public static void buy(String productID)
	{
		Log.i("IAP", "Attempt to Buy: " + productID);		
		lastPurchaseAttempt = productID;
		
		//Run on UI?
		bp.purchase(productID);
	}
	
	public static void use(String productID)
	{
		Log.i("IAP", "Attempt to consume: " + productID);
		
		//Run on UI?
		bp.consumePurchase(productID);
	}
	
	public static void subscribe(String productID)
	{
		Log.i("IAP", "Attempt to Subscribe: " + productID);		
		lastPurchaseAttempt = productID;
		
		//Run on UI?
		bp.subscribe(productID);
	}
	
	public static void restore()
	{
		Log.i("IAP", "Attempt to Restore Purchases");
	
		bp.loadOwnedPurchasesFromGoogle();
	}
	
	public static void purchaseInfo(String productID)
	{
		//Run on UI?
		final SkuDetails sd = bp.getPurchaseListingDetails(productID);
		
		GameActivity.getInstance().runOnUiThread
		(
			new Runnable()
			{ 
				public void run() 
				{
					callback.call("onProductsVerified", new Object[] {sd.productId, sd.title, sd.description, sd.priceText});
				}
			}
		);
	}
	
	public static void setPublicKey(String s)
	{		
		publicKey = s;
	}
	
	public static String getPublicKey()
	{
		return publicKey;
	}
	
	@Override
	public void onBillingInitialized() {				
		/*
		 * Called when BillingProcessor was initialized and its ready to purchase 
		 */
		Log.i("IAP", "Transaction Ready");
		
		GameActivity.getInstance().runOnUiThread
		(
			new Runnable()
			{ 
				public void run() 
				{
					callback.call("onStarted", new Object[] {});
				}
			}
		);
	}

	@Override
	public void onProductPurchased(final String productId, TransactionDetails details) 
	{
		/*
		 * Called when requested PRODUCT ID was successfully purchased
		 */
		
		Log.i("IAP", "Transaction Succeeded");
		
		GameActivity.getInstance().runOnUiThread
		(
			new Runnable()
			{ 
				public void run() 
				{
					callback.call("onPurchase", new Object[] {productId});
				}
			}
		);
	}

	@Override
	public void onBillingError(int errorCode, Throwable error) 
	{
		/*
		 * Called when some error occured. See Constants class for more details
		 */
		Log.i("IAP", "Transaction Failed");
		
		GameActivity.getInstance().runOnUiThread
		(
			new Runnable()
			{ 
				public void run() 
				{
					callback.call("onFailedPurchase", new Object[] {lastPurchaseAttempt});
					callback.call("onCanceledPurchase", new Object[] {lastPurchaseAttempt});
				}
			}
		);
	}

	@Override
	public void onPurchaseHistoryRestored() {
		/*
		 * Called when purchase history was restored and the list of all owned PRODUCT ID's 
		 * was loaded from Google Play
		 */
		Log.i("IAP", "Purchases Restored");
		
		GameActivity.getInstance().runOnUiThread
		(
			new Runnable()
			{ 
				public void run() 
				{
					callback.call("onRestorePurchases", new Object[] {});
				}
			}
		);
		
	}
}