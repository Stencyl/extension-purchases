package com.stencyl.purchases;

enum EventType {
	PURCHASE_READY;
	PURCHASE_SUCCESS;
	PURCHASE_FAIL;
	PURCHASE_CANCEL;
	PURCHASE_RESTORE;
	PURCHASE_PRODUCT_VALIDATED;
	PURCHASE_PRODUCT_VERIFIED;
}

class Purchases extends Extension
{
	public static var TYPE_IAP_CONSUMABLE = 1;
    public static var TYPE_IAP_NONCONSUMABLE = 2;

    private static var instance:Purchases;
    
    public var purchaseEvent:Event<(eventType:EventType,productID:String)->Void>;

	public static function get()
	{
		return instance;
	}

	public function new()
	{
		super();
		instance = this;
	}

	public override function loadScene(scene:Scene)
	{
		purchaseEvent = new Event<(EventType,String)->Void>();
	}
	
	public override function cleanupScene()
	{
		purchaseEvent = null;
	}
	
	public static function restorePurchases():Void
	{
	}
	
	public static function hasBought(productID:String)
	{
		return false;
	}

	public static function isPending(productID:String)
	{
		return false;
	}
	
	public static function use(productID:String)
	{
	}
	
	public static function setProductType(productID:String, productType:Int)
	{
	}
	
	public static function getQuantity(productID:String):Int
	{
		return 0;
	}

	public static function buy(productID:String):Void 
	{
	}

	public static function requestProductInfo(productIDlist:Array<Dynamic>):Void 
	{
	}

	public static function getTitle(productID:String):String 
	{
		return "";
	}
	
	public static function getDescription(productID:String):String 
	{
		return "";
	}
	
	public static function getPrice(productID:String):String 
	{
		return "";
	}
	
	public static function canBuy():Bool 
	{
		return false;
	}
	
	public static function release():Void 
	{
	}
	
	public static function validateReceipt(productID:String,password:String,URL:Bool):Void
	{
	}
}