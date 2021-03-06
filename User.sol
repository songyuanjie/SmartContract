pragma solidity ^0.4.5;
 
import "./ID.sol";
import "./Quotation.sol";
import "./UserList.sol";

contract User
{
    //仓单数据结构
    struct Receipt
    {
        string      user_id_;       //客户id
        uint        receipt_id_;    //仓单序号
        string      class_id_;      //品种id
        string      make_date_;     //产期
        string      lev_id_;        //等级
        string      wh_id_;         //仓库代码
        string      place_id_;      //产地代码
        uint        receipt_amount_;  //仓单总量
        uint        frozen_amount_;   //冻结数量   
        uint        available_amount_;//可用数量
        bool        state_;          //是否存在
    }
     
    //挂牌请求数据结构
    struct list_req_st
    {
         uint       receipt_id_;    //仓单序号
         uint       quo_id_;        //挂单编号
         uint       price_;         //价格（代替浮点型）
         uint       quo_qty_;       //挂牌量
         uint       deal_qty_;      //成交量
         uint       rem_qty_;       //剩余量
    }
    
    //合同数据结构
    struct contract_st
    {
        uint        con_data_;          //合同日期
        uint        con_id_;            //合同编号
        uint        receipt_id_;        //仓单编号
        string      buy_or_sell_;       //买卖
        uint        price_;             //价格
        uint        con_qty_;           //合同量
        //uint        fee_;               //手续费
        //uint        transfer_money_;    //已划货款
        //uint        remainder_money_;   //剩余货款
        string      user_id_;           //己方id
        string      countparty_id_;     //对手方id
        //string      trade_state_;       //交收状态
        //string      trade_type_         //交易方式
    }   
    
    //协商交易请求数据结构 发送
    struct neg_req_send_st
    {
        uint        receipt_id_;    //仓单序号
        uint        quantity_;      //交易数量
        uint        price_;         //价格
        uint        negotiate_id_;  //协商编号
        string      counterparty_id_;//对手方id
        string      trade_state;    //成交状态
    }
    
    //协商交易请求数据结构 接收
    struct neg_req_receive_st
    {
        uint        receipt_id_;        //仓单序号
        uint        quantity_;          //交易数量
        uint        price_;             //价格
        uint        negotiate_id_;      //协商编号
        string      counterparty_id_;   //对手方id
        address     sell_con_addr_;     //卖方的合约地址
        string      trade_state;        //成交状态
    }
    
    
    
     Quotation                          quatation;          //行情合约变量
     ID_contract                        ID;                 //ID合约变量
     UserList                           user_list;          //用户列表合约变量
     
     //存储仓单     
     mapping(uint => Receipt)           ReceiptMap;         //仓单ID => 仓单
        
     //存储挂牌请求     
     list_req_st[]                      list_req_array;     
     
     //存储合同
     mapping(uint => contract_st)       contract_map;       //合同编号 => 合同
     
     //协商交易请求列表
     neg_req_send_st[]                  neg_req_send_array; 
     neg_req_receive_st[]               neg_req_receive_array; 
     
     
   
     
     //打印错误信息
     event error(string,string, uint);
     
     event inform(string);
     
     
     
     //构造函数
     function User(address id_addr, address quo_addr, address user_list_addr)
     {
         ID         =   ID_contract(id_addr);
         quatation  =   Quotation(quo_addr);
         user_list  =   UserList(user_list_addr);
     }
     
    //构造仓单 "A",0,"sugar","2017","lev","wh_id","place",30
   function CreateRecipt(string user_id, uint receipt_id, string class_id,string make_date,
                        string lev_id, string wh_id, string place_id,  uint receipt_amount)
    {
        
        ReceiptMap[receipt_id] = Receipt(user_id, receipt_id,class_id, make_date, lev_id, 
                                        wh_id, place_id, receipt_amount,0,receipt_amount,true);
    }
    
    //获取持有者的仓单数量
    function getReceiptAmount(uint receipt_id) returns (uint)
    {
        return ReceiptMap[receipt_id].receipt_amount_;
    }
    
     //获取可用仓单数量
    function getAvailableAmount(uint receipt_id) returns (uint)
    {
        return ReceiptMap[receipt_id].available_amount_;
    }
    
    //减少持有者的仓单数量
    function reduceuint (uint receipt_id, uint reduece_amount) returns (bool)
    {
        if( reduece_amount > ReceiptMap[receipt_id].receipt_amount_ )
            return false;
       
         ReceiptMap[receipt_id].receipt_amount_ -= reduece_amount;
         return true;
    } 
    
     //增加持有者的仓单数量
    function increase(uint receipt_id, uint increase_amount)
    {
         ReceiptMap[receipt_id].receipt_amount_ += increase_amount;
         ReceiptMap[receipt_id].receipt_amount_ += increase_amount;
    }
    
    //冻结仓单
    function freeze(uint receipt_id, uint amount) returns (bool)
    {
        if( amount > ReceiptMap[receipt_id].receipt_amount_ )
            return false;
         ReceiptMap[receipt_id].frozen_amount_    += amount;
         ReceiptMap[receipt_id].available_amount_ -= amount;
         
         return true;
    }

    
    
    
    //挂牌请求 "zhang",0,10,20
    function ListRequire(string user_id, uint receipt_id, uint price, uint quo_qty) returns(uint quo_id )
    {
        if(ReceiptMap[receipt_id].state_ == false)
        {
             error("ListRequire():仓单序号不存在","错误代码：",uint(-2));
             return uint(-2);
        }
        if(quo_qty > ReceiptMap[receipt_id].available_amount_)  
         {
             error("ListRequire():可用仓单数量不足","错误代码：",uint(-3));
             return uint(-3);
        }
        
        freeze(receipt_id, quo_qty);//冻结仓单
        
        quatation.insert_list_1(receipt_id, "参考合约", ReceiptMap[receipt_id].class_id_, ReceiptMap[receipt_id].make_date_,
                                ReceiptMap[receipt_id].lev_id_,ReceiptMap[receipt_id].wh_id_,ReceiptMap[receipt_id].place_id_);
                                
        quo_id = quatation.insert_list_2(price, quo_qty, 0, quo_qty, 1000, "挂牌截止日",6039, user_id);
        
        if(quo_id >0)
        {
            freeze(receipt_id, quo_qty);        //冻结仓单
        }
        
        //添加挂牌请求
        list_req_array.push( list_req_st(receipt_id, quo_id, price, quo_qty, 0, quo_qty) ); 
    }
    
    //更新卖方挂牌请求
    function update_list_req(uint quo_id, uint deal_qty)
    {
        for(uint i = 0; i<list_req_array.length; i++)
        {
            if(list_req_array[i].quo_id_ == quo_id)
            {
                list_req_array[i].deal_qty_      =      deal_qty;
                list_req_array[i].rem_qty_       -=     deal_qty;
                break;
            }
        }
        
    }
    
    //摘牌请求 "li",1,10
    function delist_require(string user_id, uint quo_id, uint deal_qty) 
    {
        quatation.delist(user_id, quo_id, deal_qty);
    }
    
    //成交 创建合同
    function deal_contract(uint  receipt_id, string  buy_or_sell, uint price, uint con_qty, string countparty_id)
    {
        uint con_id = ID.contract_id();//获取合同编号
        
        contract_map[con_id].con_data_ = now;
        contract_map[con_id].con_id_ = con_id;
        contract_map[con_id].receipt_id_ = receipt_id;
        contract_map[con_id].buy_or_sell_ = buy_or_sell;
        contract_map[con_id].price_ = price;
        contract_map[con_id].con_qty_ = con_qty;
        contract_map[con_id].countparty_id_ = countparty_id;
        
        inform("成功创建合同，交易达成");
    }
    

    
    
    //发送协商交易请求 卖方调用
    function send_negotiate_req(uint receipt_id, uint price, 
                                uint quantity, string counterparty_id) returns(uint)
    {
        if(quantity > ReceiptMap[receipt_id].available_amount_)
        {
            error("negotiate_req():可用仓单数量不足","错误代码:",uint(-1));
            return uint(-1);
        }
        
        //冻结仓单
        freeze(receipt_id, quantity);
        
        
        uint    neg_id = ID.negotiate_id();//协商交易编号
        
        //更新协商交易请求列表（发送）
        neg_req_send_array.push( neg_req_send_st(receipt_id,quantity,price,
                                neg_id,counterparty_id,"未成交") );
       
        //调用对手方协商交易请求的接收方法
        User counterparty =  User( user_list.GetUserConAddr(counterparty_id) );
        counterparty.recieve_negotiate_req(receipt_id,quantity,price,
                                neg_id, ReceiptMap[receipt_id].user_id_);
        
        
    }
    
    
    //接收协商交易请求 卖方调用
    function recieve_negotiate_req(uint receipt_id, uint price, uint quantity, 
                                    uint neg_id,string counterparty_id)
    {
        neg_req_receive_array.push( neg_req_receive_st(receipt_id,quantity,price,
                                neg_id,counterparty_id,msg.sender,"未成交") );
    }
    
     //确认协商交易 买方调用此函数
    function agree_negotiate(string user_id, uint  receipt_id,  uint price,
                                uint con_qty, string countparty_id)
    {
        //创建买方合同
        deal_contract(receipt_id, "买", price,con_qty,countparty_id);
        
        //
        for(uint i= 0; i<neg_req_receive_array.length; i++ )
        {
            if(neg_req_receive_array[i].receipt_id_ == receipt_id)
                break;
        }
        //创建卖方合同
        User user_sell = User(neg_req_receive_array[i].sell_con_addr_);
        user_sell.deal_contract(receipt_id, "卖", price,con_qty,user_id);
    }
    
}




















