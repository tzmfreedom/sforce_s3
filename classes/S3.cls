public with sharing class S3 {
	public class FormKeys {
		/**
	     * POST FORM用のSignature
	     */
	    public String formSignature {get; set;}
	    
	    /**
	     * POST FORM用のRedirectURL
	     */
	    public String redirectUrl {get; set;}
	    
	    /**
	     * POST FORM用のExpire
	     */
	    public String formattedexpire {get; set;}	
	    
	    /**
	     * POST FORM用のポリシー
	     */
	    public String policy {get; set;}
	    
	    public String AWSAccessKeyID {get; set;}
	    
    
	}
	
	public class DeleteResult {
    	public Boolean isSuccess{get;set;}
    	public String key{get;set;}
    	public String code{get;set;}
    	public String message{get;set;}
    }
    
	public class BucketObject {
    	public Boolean isActionTarget {get;set;}
    	public String key {get;set;}
    	public String lastModified {get;set;}
    	public String size {get;set;}
    	public String ownername {get;set;}
    }
}