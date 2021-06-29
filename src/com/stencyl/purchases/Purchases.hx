package com.stencyl.purchases;

#if !js
import openfl.net.SharedObject;
import openfl.net.SharedObjectFlushStatus;
#end

#if android
import lime.system.JNI;
#end

import com.stencyl.Engine;
import com.stencyl.event.EventMaster;
import com.stencyl.event.StencylEvent;
import com.stencyl.behavior.Script;
import com.stencyl.behavior.TimedTask;

import lime.system.CFFI;

import openfl.events.EventDispatcher;
import openfl.events.Event;

import haxe.Json;

#if ios
@:buildXml('<include name="${haxelib:com.stencyl.purchases}/project/Build.xml"/>')
//This is just here to prevent the otherwise indirectly referenced native code from bring stripped at link time.
@:cppFileCode('extern "C" int purchases_register_prims();void com_stencyl_purchases_link(){purchases_register_prims();}')
#end
class Purchases
{	

	//Used for Android callbacks from Java
	public function new()
	{
	}
	
	public function onStarted()
	{
		trace("Purchases: Started");
		Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_READY, ""));
		
		#if android
		initialized = true;
		#end
	}

	public function onPurchase(productID:String, response:String, itemType:String, signature:String)
	{
		trace("Purchases: Successful Purchase");
		
		purchaseMap.set(productID, [response,itemType,signature]);
		
		if(hasBought(productID))
		{
			items.set(productID, Purchases.items.get(productID) + 1);
		}
			
		else
		{
			items.set(productID, 1);
		}
		
		save();
		
		Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_SUCCESS, productID));
		
	}
	
	public function onFailedPurchase(productID:String)
	{
		trace("Purchases: Failed Purchase");
		Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_FAIL, productID));
	}
	
	public function onCanceledPurchase(productID:String)
	{
		trace("Purchases: Canceled Purchase");
		Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_CANCEL, productID));
	}
	
	public function onRestorePurchases(productID:String, response:String, itemType:String, signature:String)
	{
		trace("Purchases: Restored Purchase");
		purchaseMap.set(productID, [response,itemType,signature]);
		
		if(hasBought(productID))
		{
			items.set(productID, Purchases.items.get(productID) + 1);
		}else{
			items.set(productID, 1);
		}
		
		Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_RESTORE, productID));
		
		save();
	}

	public function onProductsVerified(productID:String, title:String, desc:String, price:String)
	{
		trace("Purchases: Products Verified");
		
		detailMap.set(productID, [title,desc,price]);
		Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_PRODUCTS_VERIFIED, productID));
	}

	//---------------------------------------------

	private static var initialized:Bool = false;
	private static var items:Map<String,Int> = new Map<String,Int>();
	private static var detailMap:Map<String, Array<String>> = new Map < String, Array<String> > ();
	private static var purchaseMap:Map<String, Array<String>> = new Map < String, Array<String> > ();
	
	private static function registerHandle()
	{
		#if ios
		set_event_handle(notifyListeners);
		#end
	}
	
	private static function notifyListeners(inEvent:Dynamic)
	{
		#if ios
		var type:String = Std.string(Reflect.field(inEvent, "type"));
		var data:String = Std.string(Reflect.field(inEvent, "data"));
		
		if(type == "started")
		{
			trace("Purchases: Started");
			Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_READY, data));
		}
		
		else if(type == "success")
		{
			trace("Purchases: Successful Purchase");
			
			var productID = data;
			
			purchaseMap.set(productID, [Reflect.field(inEvent, "receiptString"),Reflect.field(inEvent, "transactionID")]);
				
			if(hasBought(productID))
			{
				items.set(productID, Purchases.items.get(productID) + 1);
			}else{
				items.set(productID, 1);
			}
			
			Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_SUCCESS, data));
			
			save();
		}
		
		else if(type == "failed")
		{
			trace("Purchases: Failed Purchase");
			Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_FAIL, data));
		}
		
		else if(type == "cancel")
		{
			trace("Purchases: Canceled Purchase");
			Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_CANCEL, data));
		}
		
		else if(type == "restore")
		{
			var productID = data;
			
			purchaseMap.set(productID, [Reflect.field(inEvent, "receiptString"),Reflect.field(inEvent, "transactionID")]);
			
			if(hasBought(productID))
			{
				items.set(productID, Purchases.items.get(productID) + 1);
			}else{
				items.set(productID, 1);
			}
			
			Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_RESTORE, data));
			
			save();
		}

		else if(type == "productsVerified")
		{
			trace("Purchases: Products Verified");
			Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_PRODUCTS_VERIFIED, data));
		}
		
		//Consumable
		if(type == "success")
		{
			var productID = data;
			
			if(hasBought(productID))
			{
				items.set(productID, Purchases.items.get(productID) + 1);
			}
			
			else
			{
				items.set(productID, 1);
			}
		
			save();
		}
		#end
	}
	
	public static function initialize(publicKey:String = ""):Void 
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
		
		var args = new Array<Dynamic>();
		args.push(publicKey);
		args.push(new Purchases());
		funcInit(args);
		#end
	}
	
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
		#if cpp
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
		#end
	}
	
	private static function save()
	{
		#if cpp
		var so = SharedObject.getLocal("in-app-purchases");
		Reflect.setField(so.data, "data", items);
		#end
		
		#if cpp
		var flushStatus:SharedObjectFlushStatus = null;
		#else
		var flushStatus:String = null;
		#end
		
		#if !js
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
		#end	
	}
	
	//True if they've bought this before. If consumable, if they have 1 or more of it.
	public static function hasBought(productID:String)
	{			
		#if mobile
		if(items == null)
		{
			return false;
		}
		
		return items.exists(productID) && items.get(productID) > 0;
		#else
		return false;
		#end
	}
	
	//Uses up a "consumable" (decrements its count by 1).
	public static function use(productID:String)
	{
		#if mobile
		if(hasBought(productID))
		{
			items.set(productID, items.get(productID) - 1);
			save();
		}
		#end
			
	}
	
	//Allows item to be rebought on Android without consuming local count
	public static function consume(productID:String)
	{		
		#if android
		if(purchaseMap.exists(productID))
		{
			if (funcConsume == null) {
				funcConsume = JNI.createStaticMethod ("com/stencyl/android/AndroidBilling", "consume", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
			}
			
			funcConsume (purchaseMap.get(productID)[0], purchaseMap.get(productID)[1], purchaseMap.get(productID)[2]);
		}
		#end
	}
	
	public static function getQuantity(productID:String):Int
	{
		#if mobile
		if(hasBought(productID))
		{
			return items.get(productID);
		}
		#end
		
		return 0;
	}

	public static function buy(productID:String):Void 
	{
		#if ios
		purchases_buy(productID);
		#end	
		
		#if android
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
			return detailMap.get(productID)[0];
		}
		#end
		
		return "None";
	}
	
	public static function getDescription(productID:String):String 
	{
		#if ios
		return purchases_desc(productID);
		#end
		
		#if android	
		if (detailMap.get(productID) != null)
		{
			return detailMap.get(productID)[1];
		}
		#end
		
		return "None";
	}
	
	public static function getPrice(productID:String):String 
	{
		#if ios
		return purchases_price(productID);
		#end
		
		#if android	
		if (detailMap.get(productID) != null)
		{
			return detailMap.get(productID)[2];
		}
		#end
		
		return "None";
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
		var receiptVar = purchaseMap.get(productID)[0];
		
		purchases_validate(receiptVar,password,URL);
		
		Script.runLater(1000 * 2, function(timeTask:TimedTask):Void
		{
			if(purchases_validate(receiptVar,password,URL)){
		
			Engine.events.addPurchaseEvent(new StencylEvent(StencylEvent.PURCHASE_PRODUCT_VALIDATED, productID));
			}
			
		}, null);
		#end
	}
	
	#if android	
	private static var funcInit:Dynamic;
	private static var funcBuy:Dynamic;
	private static var funcConsume:Dynamic;
	private static var funcSub:Dynamic;
	private static var funcRestore:Dynamic;
	private static var funcRelease:Dynamic;
	private static var funcTest:Dynamic;
	private static var funcPurchaseInfo:Dynamic;
	private static var funcSubInfo:Dynamic;
	private static var funcIsPurchased:Dynamic;
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