/**
 * S3 REST用のコントローラ
 */
public with sharing class S3RestController {
	/**
	 * バケット内のオブジェクトリスト
	 */
	public List<S3.BucketObject> objList {get; set;}
    
    /**
     * AWSの各クレデンシャル
     */
    private final String AWS_ACCESS_KEY_ID = EnvSetting__c.getOrgDefaults().AWSAccessKeyID__c;
    
    private final String AWS_ACCESS_KEY_SECRET = EnvSetting__c.getOrgDefaults().AWSAccessKeySecret__c;
    
    /**
     * デフォルトのバケット名(URLパラメータで指定がなければこのバケット名が使用される)
     */
    private final String DEFAULT_BUCKETNAME = 'testbucket';
    
    
    /**
     * S3共通クラス
     */
    private S3RestCommon s3cls {get;set;}
    
    /**
     * POST Form用のパラメータ格納DTO
     */
    public S3.FormKeys formKeys {get;set;}
    
    /**
     * PUT用のキー
     */
    public String postKey {get; set;}
    
    /**
     * 削除用のキー
     */
    public String deleteKey {get;set;}
    
    /**
     * アップロードファイル(Blob)
     */
    public Blob file {get;set;}
    
    /**
     * URLパラメータ
     */
    private Map<String, String> params {get;set;}
    
    /**
     * バケット名のゲッター
     */
    public String getBucketName() {
    	return this.s3cls.bucketName;
    }
    
    public S3RestController() {
    	//バケットの設定
    	String bucketName = DEFAULT_BUCKETNAME;
    	if (!String.isBlank(ApexPages.currentPage().getParameters().get('bucketname'))) {
    		bucketName = ApexPages.currentPage().getParameters().get('bucketname');
    	}
    	//S3クラス生成
    	this.s3cls = new S3RestCommon(AWS_ACCESS_KEY_ID, AWS_ACCESS_KEY_SECRET, bucketName);
    	
    	this.params = ApexPages.currentPage().getParameters();
    }
    
    /**
     * バケット内のオブジェクトをリストアップ
     */
    public PageReference listS3Object() {
    	Map<String, String> listParams = new Map<String, String>();
    	//prefixパラメータがあれば、リストのprefixで抽出
    	if (this.params.containsKey('prefix')) {
    		listParams.put('prefix', this.params.get('prefix'));
    	}
    	
    	//delimiterパラメータがあれば、リストのdelimiterで抽出
    	if (this.params.containsKey('delimiter')) {
    		listParams.put('delimiter', this.params.get('delimiter'));
    	}
    	
    	
    	this.objList = this.s3cls.listBucketObject(listParams);
    	return null;
    }
    
    /**
     * アップロードフォーム画面用の初期化処理
     */
    public PageReference formInit() {
    	if (this.setS3KeyName()) {
    		return new PageReference('/' + this.params.get('id'));
    	}
    	
    	//POST Form用のExpireを生成
    	DateTime expire = system.now().addDays(1);
    	String formattedexpire = expire.formatGmt('yyyy-MM-dd') + 'T' + expire.formatGmt('HH:mm:ss') + '.' + expire.formatGMT('SSS') + 'Z';
    	this.formKeys = this.s3cls.getFormKeys(formattedexpire, URL.getSalesforceBaseUrl().toExternalForm() + '/apex/UploadS3?id=' + params.get('id') + '&mode=updatecontact');
    	
    	return null;
    }
    
    /**
     * ファイルをPUT
     */
    public PageReference postFile() {
    	this.s3cls.postFile(postKey, file, null);
    	this.objList = this.s3cls.listBucketObject(null);
    	return null;
    }
    
    /**
     * ファイルを削除
     */
    public PageReference deleteBucketObject() {
    	//deletekeyを削除し、オブジェクトを再度取得
    	this.s3cls.deleteBucketObject(this.deleteKey, null);
    	this.objList = this.s3cls.listBucketObject(null);
    	return null;
    }
    
    
    /**
     * ファイルを複数件削除
     */
    public PageReference multipleDelete() {
    	//チェックがついているオブジェクトのみ削除する。
    	List<String> deleteKeyList = new List<String>();
    	for (S3.BucketObject obj : objList) {
    		if (obj.isActionTarget) {
	    		deleteKeyList.add(obj.key);
    		}
    	}
    	
    	//削除処理と削除結果のパース
    	List<S3.DeleteResult> droList = this.s3cls.multipleDelete(deleteKeyList, null);
    	//削除結果をページメッセージで表示
    	for (S3.DeleteResult dro : droList) {
    		if (dro.isSuccess) {
    			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, '[' + dro.key + ']の削除に成功しました。'));
    		} else {
    			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, '[' + dro.key + ']の削除に失敗しました。<' + dro.code + ':' + dro.message + '>'));
    		}
    	}
    	//再度リストを取得する
    	this.objList = this.s3cls.listBucketObject(null);
    	return null;
    }
    
    //今はContactに画像を紐付けている
    public Boolean setS3KeyName() {
    	//S3サーバからリダイレクトされてきて、対象顧客が取得出来れば、キーとバケット名の更新を行う
    	if (this.params.get('mode') == 'updatecontact') {
    		List<Contact> conList = [
    			SELECT
    				id,
    				S3KeyName__c,
    				S3BucketName__c
    			FROM
    				Contact
    			WHERE
    				id = :this.params.get('id')
    		];
    		
    		if (!conList.isEmpty()) {
    			//キー名が変更された場合は元のファイルを削除
    			if (conList[0].S3KeyName__c != params.get('key')) {
    				this.s3cls.deleteBucketObject(conList[0].S3KeyName__c, null);
    			}
    			conList[0].S3KeyName__c = params.get('key');
    			conList[0].S3BucketName__c = params.get('bucket');
    			update conList[0];
    			//対象顧客ページへ画面遷移
    			return true;
    		}
    	}
    	return false;
    }
}