package com.stencyl.purchases;

import com.stencyl.Extension;
import com.stencyl.behavior.Script;
import com.stencyl.behavior.TimedTask;
import com.stencyl.event.Event;
import com.stencyl.models.Scene;
import com.stencyl.utils.Utils;

#if ios
import lime.system.CFFI;
#elseif android
import lime.system.JNI;
#end

import openfl.net.SharedObject;
import openfl.net.SharedObjectFlushStatus;

using com.stencyl.event.EventDispatcher;

#if ios
typedef PurchaseDetails = {
	var receiptString:String;
	var transactionID:String;
}
#elseif android
typedef PurchaseDetails = {
	var purchaseToken:String;
	var purchaseState:Int;
	var isAcknowledged:Bool;
}
typedef ProductDetails = {
	var title:String;
	var description:String;
	var price:String;
}
#end

typedef PurchaseEventData = {
	var eventType:EventType;
	var productID:String;
}

enum EventType {
	PURCHASE_READY;
	PURCHASE_SUCCESS;
	PURCHASE_FAIL;
	PURCHASE_CANCEL;
	PURCHASE_RESTORE;
	PURCHASE_PRODUCT_VALIDATED;
	PURCHASE_PRODUCT_VERIFIED;
}

#if ios
@:buildXml('<include name="${haxelib:com.stencyl.purchases}/project/Build.xml"/>')
//This is just here to prevent the otherwise indirectly referenced native code from bring stripped at link time.
@:cppFileCode('extern "C" int purchases_register_prims();void com_stencyl_purchases_link(){purchases_register_prims();}')
#end
class Purchases extends Extension
{
	public static final TYPE_IAP_CONSUMABLE = 1;
    public static final TYPE_IAP_NONCONSUMABLE = 2;

	private static var instance:Purchases;

	private static var initialized:Bool = false;
	private static var items:Map<String,Int> = new Map<String,Int>();
	#if android
	private static var detailMap:Map<String, ProductDetails> = new Map < String, ProductDetails > ();
	#end
	private static var productTypeMap:Map<String, Int> = new Map < String, Int > ();
	private static var purchaseMap:Map<String, PurchaseDetails> = new Map < String, PurchaseDetails > ();
	
	//stencyl events
	public var purchaseEvent:Event<(eventType:EventType,productID:String)->Void>;
	public var nativeEventQueue:Array<PurchaseEventData> = [];

	public static function get()
	{
		return instance;
	}

	public function new()
	{
		super();
		instance = this;
	}

	public override function initialize():Void 
	{
		#if ios
		if(!initialized)
		{
			set_event_handle(notifyListeners);
			load();
			
			initialized = true;
		}
		
		purchases_initialize();
		#end	
		
		#if android
		if(funcInit == null)
		{
			funcInit = JNI.createStaticMethod("com/stencyl/android/AndroidBilling", "initialize", "(Ljava/lang/String;Lorg/haxe/lime/HaxeObject;)V", true);
			load();			
		}
		
		PurchasesConfig.load();

		var args = new Array<Dynamic>();
		args.push(PurchasesConfig.androidPublicKey);
		args.push(this);
		funcInit(args);
		#end
	}

	//Stencyl event plumbing

	public override function loadScene(scene:Scene)
	{
		purchaseEvent = new Event<(EventType,String)->Void>();
	}
	
	public override function cleanupScene()
	{
		purchaseEvent = null;
	}

	public override function preSceneUpdate()
	{
		for(event in nativeEventQueue)
		{
			purchaseEvent.dispatch(event.eventType, event.productID);
		}
		nativeEventQueue.splice(0, nativeEventQueue.length);
	}

	//Design Mode blocks
	
	public static function restorePurchases():Void
	{
		#if ios
		purchases_restore();
		#end
		
		#if android
		if(funcRestore == null)
		{
			funcRestore = JNI.createStaticMethod("com/stencyl/android/AndroidBilling", "restore", "()V", true);
		}
		
		funcRestore([]);
		#end
	}
	
	private static function load()
	{
		try 
		{
			var data = SharedObject.getLocal("in-app-purchases");
			var saveData = Reflect.field(data.data, "data");
			
			if(saveData != null)
			{
				items = saveData;
				trace(items);
			}					
		}
		
		catch(e:Dynamic) 
		{
			trace("Error! Failed to load purchases: " + e);
		}
	}
	
	private static function save()
	{
		var so = SharedObject.getLocal("in-app-purchases");
		Reflect.setField(so.data, "data", items);
		
		var flushStatus:SharedObjectFlushStatus = null;
		
		try 
		{
		    flushStatus = so.flush();
		} 
		
		catch(e:Dynamic) 
		{
			trace("Error! Failed to save purchases: " + e);
		}
		
		if(flushStatus != null) 
		{
		    switch(flushStatus) 
		    {
		        case SharedObjectFlushStatus.PENDING:
		            trace("Requesting Permission to Save Purchases");
		            
		        case SharedObjectFlushStatus.FLUSHED:
		            trace("Saved Purchases");
		    }
		}
	}
	
	//True if they've bought this before. If consumable, if they have 1 or more of it.
	public static function hasBought(productID:String)
	{
		return getCount(productID) > 0;
	}

	private static function getCount(productID:String)
	{
		return items.exists(productID) ? items.get(productID) : 0;
	}

	private static function changeCount(productID:String, amount:Int)
	{
		items.set(productID, getCount(productID) + amount);
	}

	public static function isPending(productID:String)
	{
		#if android
		if(purchaseMap == null)
		{
			return false;
		}
		
		return purchaseMap.exists(productID) && purchaseMap.get(productID).purchaseState == PENDING;
		#else
		return false;
		#end
	}
	
	//Uses up a "consumable" (decrements its count by 1).
	public static function use(productID:String)
	{
		if(getCount(productID) > 0)
		{
			changeCount(productID, -1);
			save();
		}
	}

	public static function setProductType(productID:String, productType:Int)
	{
		productTypeMap.set(productID, productType);
		#if android
		acknowledgePurchase(productID);
		#end
	}

	#if android
	private static function acknowledgePurchase(productID:String)
	{
		var purchase = purchaseMap.get(productID);
		if(purchase != null && purchase.purchaseState == PURCHASED && !purchase.isAcknowledged)
		{
			if(productTypeMap.get(productID) == TYPE_IAP_CONSUMABLE)
			{
				if (funcConsume == null) {
					funcConsume = JNI.createStaticMethod ("com/stencyl/android/AndroidBilling", "consume", "(Ljava/lang/String;)V");
				}
				
				funcConsume (purchase.purchaseToken);
				purchase.isAcknowledged = true;
				instance.nativeEventQueue.push({"eventType": PURCHASE_SUCCESS, "productID": productID});
			}
			else if(productTypeMap.get(productID) == TYPE_IAP_NONCONSUMABLE)
			{
				if (funcAcknowledge == null) {
					funcAcknowledge = JNI.createStaticMethod ("com/stencyl/android/AndroidBilling", "acknowledge", "(Ljava/lang/String;)V");
				}
				
				funcAcknowledge (purchase.purchaseToken);
				purchase.isAcknowledged = true;
				instance.nativeEventQueue.push({"eventType": PURCHASE_SUCCESS, "productID": productID});
			}
		}
	}
	#end
	
	public static function getQuantity(productID:String):Int
	{
		return getCount(productID);
	}

	public static function buy(productID:String):Void 
	{
		#if ios
		purchases_buy(productID);
		#end	
		
		#if android
		if(!productTypeMap.exists(productID))
		{
			trace("Error: product \"" + productID + "\" hasn't been set as consumable/nonconsumable yet.");
		}

		if(funcBuy == null)
		{
			funcBuy = JNI.createStaticMethod("com/stencyl/android/AndroidBilling", "buy", "(Ljava/lang/String;)V", true);
		}
		
		funcBuy([productID]);
		#end	
	}

	public static function requestProductInfo(productIDlist:Array<Dynamic>):Void 
	{
		var productIDcommalist:String = productIDlist.join(",");
		
		#if ios		
		purchases_requestProductInfo(productIDcommalist);
		#end
		
		#if android
		if(funcPurchaseInfo == null)
		{
			funcPurchaseInfo = JNI.createStaticMethod("com/stencyl/android/AndroidBilling", "purchaseInfo", "(Ljava/lang/String;)V", true);
		}
		
		funcPurchaseInfo([productIDcommalist]);
		#end
	}

	public static function getTitle(productID:String):String 
	{
		#if ios
		return purchases_title(productID);
		#end
		
		#if android	
		if (detailMap.get(productID) != null)
		{
			return detailMap.get(productID).title;
		}
		
		return "None";
		#end
	}
	
	public static function getDescription(productID:String):String 
	{
		#if ios
		return purchases_desc(productID);
		#end
		
		#if android	
		if (detailMap.get(productID) != null)
		{
			return detailMap.get(productID).description;
		}
		
		return "None";
		#end
	}
	
	public static function getPrice(productID:String):String 
	{
		#if ios
		return purchases_price(productID);
		#end
		
		#if android	
		if (detailMap.get(productID) != null)
		{
			return detailMap.get(productID).price;
		}
		
		return "None";
		#end
	}
	
	public static function canBuy():Bool 
	{
		#if ios
		return purchases_canbuy();
		#else
		return initialized;
		#end
	}
	
	public static function release():Void 
	{
		#if ios
		purchases_release();
		#end
		
		#if android
		if(funcRelease == null)
		{
			funcRelease = JNI.createStaticMethod("com/stencyl/android/AndroidBilling", "release", "()V", true);
		}
		
		funcRelease([]);
		#end
	}
	
	public static function validateReceipt(productID:String,password:String,URL:Bool):Void{
		#if ios
		var receiptVar = purchaseMap.get(productID).receiptString;
		
		purchases_validate(receiptVar,password,URL);
		
		Script.runLater(1000 * 2, function(timeTask:TimedTask):Void
		{
			if(purchases_validate(receiptVar,password,URL))
			{
				instance.nativeEventQueue.push({"eventType": PURCHASE_PRODUCT_VALIDATED, "productID": productID});
			}
			
		}, null);
		#end
	}

	//Callbacks

	#if android
	private static final PURCHASED:Int = 1;
    private static final PENDING:Int = 2;

    public function onStarted(result:String)
	{
		if(result == "Success")
		{
			trace("Purchases: Started");
			instance.nativeEventQueue.push({"eventType": PURCHASE_READY, "productID": ""});
			
			initialized = true;
		}
		else
		{
			trace("Purchases: Failed to start");
		}
	}

    public function onPurchase(productID:String, purchaseToken:String, purchaseState:Int, isAcknowledged:Bool)
	{
		trace("Purchases: Successful Purchase");
		
		var purchase = {"purchaseToken": purchaseToken, "purchaseState": purchaseState, "isAcknowledged": isAcknowledged};
		purchaseMap.set(productID, purchase);
		
		if(purchaseState == PURCHASED && !isAcknowledged)
		{
			changeCount(productID, 1);
			
			save();
			acknowledgePurchase(productID);
		}
	}
	
	public function onFailedPurchase(productID:String)
	{
		trace("Purchases: Failed Purchase");
		instance.nativeEventQueue.push({"eventType": PURCHASE_FAIL, "productID": productID});
	}
	
	public function onCanceledPurchase(productID:String)
	{
		trace("Purchases: Canceled Purchase");
		instance.nativeEventQueue.push({"eventType": PURCHASE_CANCEL, "productID": productID});
	}
	
	public function onRestorePurchases(productID:String, purchaseToken:String, purchaseState:Int, isAcknowledged:Bool)
	{
		trace("Purchases: Restored Purchase");

		var purchase = {"purchaseToken": purchaseToken, "purchaseState": purchaseState, "isAcknowledged": isAcknowledged};
		purchaseMap.set(productID, purchase);
		
		//only changeCount if count is 0 (this is a new device) or if the purchase has not yet been acknowledged.
		if(purchaseState == PURCHASED && (getCount(productID) == 0 || !isAcknowledged))
		{
			changeCount(productID, 1);
			
			save();
			if(!isAcknowledged)
			{
				acknowledgePurchase(productID);
			}
			else
			{
				instance.nativeEventQueue.push({"eventType": PURCHASE_RESTORE, "productID": productID});
			}
		}
	}

	public function onProductsVerified(productID:String, title:String, desc:String, price:String)
	{
		trace("Purchases: Products Verified");
		
		detailMap.set(productID, {"title": title, "description": desc, "price": price});
		instance.nativeEventQueue.push({"eventType": PURCHASE_PRODUCT_VERIFIED, "productID": productID});
	}
	#end

	#if ios
	private static function registerHandle()
	{
		set_event_handle(notifyListeners);
	}
	
	private static function notifyListeners(inEvent:Dynamic)
	{
		var type:String = Std.string(Reflect.field(inEvent, "type"));
		var data:String = Std.string(Reflect.field(inEvent, "data"));
		
		if(type == "started")
		{
			trace("Purchases: Started");
			instance.nativeEventQueue.push({"eventType": PURCHASE_READY, "productID": ""});
		}
		
		else if(type == "success")
		{
			trace("Purchases: Successful Purchase");
			
			var productID = data;
			
			purchaseMap.set(productID, {
				"receiptString": Reflect.field(inEvent, "receiptString"),
				"transactionID": Reflect.field(inEvent, "transactionID")
			});
			
			changeCount(productID, 1);
			
			instance.nativeEventQueue.push({"eventType": PURCHASE_SUCCESS, "productID": data});
			
			save();
		}
		
		else if(type == "failed")
		{
			trace("Purchases: Failed Purchase");
			instance.nativeEventQueue.push({"eventType": PURCHASE_FAIL, "productID": data});
		}
		
		else if(type == "cancel")
		{
			trace("Purchases: Canceled Purchase");
			instance.nativeEventQueue.push({"eventType": PURCHASE_CANCEL, "productID": data});
		}
		
		else if(type == "restore")
		{
			var productID = data;
			
			purchaseMap.set(productID, {
				"receiptString": Reflect.field(inEvent, "receiptString"),
				"transactionID": Reflect.field(inEvent, "transactionID")
			});
			
			changeCount(productID, 1);
			
			instance.nativeEventQueue.push({"eventType": PURCHASE_RESTORE, "productID": data});
			
			save();
		}

		else if(type == "productsVerified")
		{
			trace("Purchases: Products Verified");
			instance.nativeEventQueue.push({"eventType": PURCHASE_PRODUCT_VERIFIED, "productID": data});
		}
		
		//Consumable
		if(type == "success")
		{
			var productID = data;
			
			changeCount(productID, 1);
		
			save();
		}
	}
	#end

	//Foreign functions
	
	#if android	
	private static var funcInit:Dynamic;
	private static var funcBuy:Dynamic;
	private static var funcAcknowledge:Dynamic;
	private static var funcConsume:Dynamic;
	private static var funcRestore:Dynamic;
	private static var funcRelease:Dynamic;
	private static var funcPurchaseInfo:Dynamic;
	#end

	#if ios
	private static var purchases_initialize = CFFI.load("purchases", "purchases_initialize", 0);
	private static var purchases_restore = CFFI.load("purchases", "purchases_restore", 0);
	private static var purchases_buy = CFFI.load("purchases", "purchases_buy", 1);
	private static var purchases_canbuy = CFFI.load("purchases", "purchases_canbuy", 0);
	private static var purchases_release = CFFI.load("purchases", "purchases_release", 0);
	private static var purchases_requestProductInfo = CFFI.load("purchases", "purchases_requestProductInfo", 1);
	private static var purchases_title = CFFI.load("purchases", "purchases_title", 1);
	private static var purchases_desc = CFFI.load("purchases", "purchases_desc", 1);
	private static var purchases_price = CFFI.load("purchases", "purchases_price", 1);
	private static var set_event_handle = CFFI.load("purchases", "purchases_set_event_handle", 1);
	private static var purchases_validate = CFFI.load("purchases", "purchases_validate", 3);
	#end
}