package com.stencyl.purchases;

class Purchases
{
	public static var TYPE_IAP_CONSUMABLE = 1;
    public static var TYPE_IAP_NONCONSUMABLE = 2;
    
	public static function initialize(publicKey:String = ""):Void 
	{
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