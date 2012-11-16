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
	public static void initialize(String publicKey)
	{
		Log.i("IAP", "Attempt to init billing service");
	
		setPublicKey(publicKey);
		
		GameActivity.getInstance().runOnUiThread(new Runnable() 
		{
			public void run() 
			{
				GameActivity.getInstance().startService(new Intent(GameActivity.getInstance(), BillingService.class));
		
				Handler transactionHandler = new Handler()
				{
					public void handleMessage(android.os.Message msg) 
					{
						if(BillingHelper.latestPurchase != null)
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
						}
						
						else
						{
							//FAILED
						}
					};     
				};
				
				BillingHelper.setCompletedHandler(transactionHandler);
			}
		});
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