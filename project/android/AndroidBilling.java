import com.blundell.test.*;
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

public class AndroidBilling
{
	public static void initialize(final String publicKey)
	{
		setPublicKey(publicKey);
		GameActivity.getInstance().startService(new Intent(GameActivity.getInstance(), BillingService.class));
		BillingHelper.setCompletedHandler(transactionHandler);
	}
	
	public static void buy(String productID)
	{
		if(BillingHelper.isBillingSupported())
		{
        	BillingHelper.requestPurchase(GameActivity.getInstance(), productID);
        }
        
        else 
        {
	       	Log.i("IAP", "Can't purchase on this device");
	    }
	}
	
	private static Handler transactionHandler = new Handler()
	{
		public void handleMessage(android.os.Message msg) 
		{
			Log.i("IAP", "Transaction Complete");
			Log.i("IAP", "Transaction Status: " + BillingHelper.latestPurchase.purchaseState);
			Log.i("IAP", "Attempted to Purchase: " + BillingHelper.latestPurchase.productId);

			if(BillingHelper.latestPurchase.isPurchased())
			{
				//SUCCESS
			} 
			
			else 
			{
				//FAILURE
			}
		};     
	};
	
	private static String publicKey = "";
	
	public static void setPublicKey(String s)
	{
		publicKey = s;
	}
	
	public static String getPublicKey()
	{
		return publicKey;
	}
}