//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright "MK"
#property link "https://www.mql5.com"
#property version "1.0"
#property strict

//-----------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------

#define PriceBufforSize 250
#define PriceBufforSizeFast 250
#define TickBufforSize 10000

string comment = "FREEDOM";
string Version = "FREEDOM";
string Parameters = "Please set your values";


int MAX_ORDER_ITERATION = 5;
bool K3_FALCON_FX = true;
input string Trade_Comment_desc = "Trades captured by ALGO will be visible with comment below:";
input string Trade_Comment = "FREEDOM";

input double Lot_Size = 1;
input double ATR_SL = 0.75;
input double ATR_TP = 1.75;
input double Max_SL = 10000;

bool CanOpen = true;

input int StartTime_HH = 16;
input int StartTime_MM = 0;
input int EndTime_HH = 22;
input int EndTime_MM = 0;

bool duringWorkingHours = false;

// zmienne 
int total;

input int Trade_Reference = 1;
input int Max_Trades_Amount = 5;
input int Max_Spread = 75;
input double FreeMargin = 300.0;
input string Advanced_config = "Additional configuration for advanced users";
input bool TP_Dynamic = true;
input bool Infinite_SL = false;
input bool HalfTP_SL = true;
input bool ConstSL = false;
int Slippage = 2;
input bool use_ATR_size = true;
input double ATR_min_size = 15;
input double ATR_max_size = 75;
bool use_ATR_atrSL = true;
double Min_atrSL = 0.2;
input double DeviationTickDelta = 4.5;
input double avgTickSpaceValue = 1.25;
input double MINspeed15sec = 3;
input double SpeedIncreased = 1.2;
input int LastTickNumber = 90; 
input double TickThreshold = 0.55;
input bool RatioATRCheck = true;
input double M1_ATR5vsATR14 = 1.00;
input double M15_ATR5vsATR14 = 1.05;
bool OneCandleOnly = true;
input bool Activated_below = true;
input int Max_Consecutive_Losses = 3;
input int Cooldown_After_Loss_Minutes = 30;
input int Min_Minutes_Between_Trades = 5;


/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Global variables
double priceBuffer[PriceBufforSize];       // Circular buffer
int bufferIndex = 0;           // Current index in the buffer
int bufferCount = 0;           // Number of elements in the buffer 
double avgTickSpace = 0;       // Average tick space
datetime tickTimeBuffer[TickBufforSize];
int tickBufferIndex = 0;
int tickBufferCount = 0;
double speedTick15Sec = 0;
double speedTick5Sec = 0;
double speedTickPrev5Sec = 0;
double tickBuffer[];
int bufferSize = 0;
double upRatio = 0;
double downRatio = 0;
double lastM1Open = 0;
bool IsNewM1Candle = false;
double currentM1Open = 0;
double priceBufferFast[PriceBufforSizeFast];       // Circular buffer Fast
int bufferIndexFast = 0;           // Current index in the buffer Fast
int bufferCountFast = 0;  
double fastTickSpace = 0;       // Fast tick space

int DayCurrent;
int amountOfTrades = 0;
double MarketPoint_size = MarketInfo(Symbol(),MODE_POINT);
double MarketLot_size = MarketInfo(Symbol(),MODE_LOTSIZE);
int consecutiveLosses = 0;
datetime cooldownUntil = 0;
datetime lastTradeOpenTime = 0;
datetime lastHistoryCloseTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   MarketPoint_size = MarketInfo(Symbol(),MODE_POINT);
   MarketLot_size = MarketInfo(Symbol(),MODE_LOTSIZE);
   ArrayResize(tickBuffer, LastTickNumber);
   bufferSize = 0;
   DayCurrent = Day();
   consecutiveLosses = 0;
   cooldownUntil = 0;
   lastTradeOpenTime = 0;
   lastHistoryCloseTime = 0;


  // if (K3_FALCON_FX == true)

   Comment("FREEDOM is running !!!");

  // int period = Period();

   return (INIT_SUCCEEDED); 
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){}

void OnTick()
{
   UpdateClosedTradeStats();

   double atrSL = iATR(NULL,PERIOD_M1,4,1);
   //AvgTickSpace//
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Get the current price
   UpdateAveragePriceChange(currentPrice);
   UpdateDeviation(currentPrice);
   //Tick Speed//
   UpdateTickSpeeds();
   UpDownRatio();
   double M1_RatioATR5 = iATR(NULL,PERIOD_M1,5,0);
   double M1_RatioATR14 = iATR(NULL,PERIOD_M1,14,0);
   double M15_RatioATR5 = iATR(NULL,PERIOD_M15,5,1);
   double M15_RatioATR14 = iATR(NULL,PERIOD_M15,14,1);
   double M1_ATR5vATR14 = M1_RatioATR5/M1_RatioATR14;
   double M15_ATR5vATR14 = M15_RatioATR5/M15_RatioATR14;
   
   
   Comment(" "+"\nATR_Size:  "+NormalizeDouble(atrSL,2)+"   ||   M1_ATR5vATR14:  "+NormalizeDouble(M1_ATR5vATR14,2)+"   ||   M15_ATR5vATR14:  "+NormalizeDouble(M15_ATR5vATR14,2)+"   ||   TickSpeed15Sec:  "+NormalizeDouble(speedTick15Sec,2)+"   ||   AvgTickSpace:  "+NormalizeDouble(avgTickSpace,4)+"   ||   DeviationTickSpace:  "+NormalizeDouble(fastTickSpace,4)+"   ||   LossStreak:  "+consecutiveLosses);
 
   total = OrdersTotal();
   numberOfTotalTrades();
   int currHour = Hour();
   int currMin = Minute();

   if (((currHour > StartTime_HH ) || (currHour == StartTime_HH && currMin >= StartTime_MM)) && ((currHour <= (EndTime_HH - 1)) || (currHour == EndTime_HH && currMin <= EndTime_MM))){    
      duringWorkingHours = true;
   }
   else
   {
      duringWorkingHours = false;
   }
   int cnt, OrdersValidation, minNumberOfPositions;

   int total_per_robot = 0;

   if (total < Max_Trades_Amount && duringWorkingHours)
   {
      if (!CanOpen)
      
      {
         if (DayCurrent != Day())
         {
            CanOpen = true;
         }
      }

      if (AccountFreeMargin() < FreeMargin)
      {
         CanOpen = false;
         DayCurrent = Day();
         Print("We have no money. FreeMargin in below minmum: ", AccountFreeMargin());
      }
      else
      {
            if (CanOpen && (!Activated_below || CanOpenNewTrade()))
            {
               if (isFastLong_RSI())
               {
                  if (openLongRC_RSI())
                  {
                  }
               }
               else if (isFastShort_RSI())
               {
                  if (openShortRC_RSI())
                  {
                  }
               }
            }

         
      }
   }

   total = OrdersTotal(); // toDO! usunac strategie
   if (total > 0)
   {
             
      // policz ile lacznie pozycji
      int totalBuy = 0;
      int totalSell = 0;

      for (int cnt = 0; cnt < total; cnt++)
      {
         if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
         {
            continue;
         }
         RefreshRates();
         int orderMagicNumber = OrderMagicNumber();

         if (orderMagicNumber == Trade_Reference)
         {
            if (OrderSymbol() == Symbol())
            {
               if (OrderType() == OP_BUY)
               {
                  
                     modif_Buy(); 
                     
               } 
               if (OrderType() == OP_SELL)
               {
                  
                     modif_Sell();
                
                     
               }
            }
         }
      }

      
      if (use_ATR_atrSL)
      {
      double atrSL = iATR(NULL,PERIOD_M1,4,1);
                 
       if(atrSL*(1+Min_atrSL) < ATR_min_size){
         

            int maxIter = 5;
            bool closeStatus = false;
            do
            {
               closeStatus = closeAllWolfsWithHG();
               maxIter--;
            } while (maxIter > 0 && !closeStatus);
         }
      }

  }

}

double ClampLotSize(double lots)
{
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);

   if (lotStep <= 0)
      lotStep = 0.01;

   lots = MathFloor(lots / lotStep) * lotStep;
   if (lots < minLot)
      lots = minLot;
   if (lots > maxLot)
      lots = maxLot;

   return NormalizeDouble(lots, 2);
}

double CalculateOrderLots()
{
   return ClampLotSize(Lot_Size);
}

void UpdateClosedTradeStats()
{
   int totalHistory = OrdersHistoryTotal();
   if (totalHistory <= 0)
      return;

   datetime newestProcessed = lastHistoryCloseTime;

   for (int i = totalHistory - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if (OrderSymbol() != Symbol() || OrderMagicNumber() != Trade_Reference)
         continue;

      datetime closeTime = OrderCloseTime();
      if (closeTime <= lastHistoryCloseTime)
         break;

      double netProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if (netProfit < 0)
      {
         consecutiveLosses++;
         if (consecutiveLosses >= Max_Consecutive_Losses)
            cooldownUntil = TimeCurrent() + Cooldown_After_Loss_Minutes * 60;
      }
      else if (netProfit > 0)
      {
         consecutiveLosses = 0;
      }

      if (closeTime > newestProcessed)
         newestProcessed = closeTime;
   }

   lastHistoryCloseTime = newestProcessed;
}

bool CanOpenNewTrade()
{
   if (cooldownUntil > TimeCurrent())
      return false;

   if (lastTradeOpenTime > 0 && (TimeCurrent() - lastTradeOpenTime) < Min_Minutes_Between_Trades * 60)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| MAIN ALGO                                            |
//+------------------------------------------------------------------+

  bool openShortRC_RSI()
  {
  
    bool FREEDOM = false;

      RefreshRates();
      double Ichimoku_SL_value = Ichimoku_SL_SELL();
      if(Ichimoku_SL_value > 0.0 && canOpen_Spread()){
      double lotToUse = CalculateOrderLots();
      int ticket = OrderSend(Symbol(), OP_SELL, lotToUse, Bid, Slippage,NormalizeDouble((Ichimoku_SL_value),Digits()), NormalizeDouble(0,Digits()), Trade_Comment, Trade_Reference, 0, Yellow);

      if (ticket > 0)
      {    
          Print("Short Sleep Well opened : ", OrderOpenPrice());
          FREEDOM = true;
          IsNewM1Candle = false;
          lastTradeOpenTime = TimeCurrent();
      }
      else
      {
        Print("Cannot open short position : ", GetLastError());
        FREEDOM = false;
      }
    }
    

    return FREEDOM;
 }  
 
  double Ichimoku_SL_SELL(){
  
  double atrSL = iATR(NULL,PERIOD_M1,4,1);
  
  double above_Candle_SL = Ask + (ATR_SL*atrSL);
  double check = Ask + (Max_SL*Point());
  
  if(above_Candle_SL > 0 && above_Candle_SL < check){
      return above_Candle_SL;
     }else{
     return check;
     }

  return 0;
}

bool openLongRC_RSI() {

  bool FREEDOM = false;
 
    RefreshRates();
    double Ichimoku_SL_value = Ichimoku_SL_BUY();
    if(Ichimoku_SL_value > 0.0 && canOpen_Spread()){
    double lotToUse = CalculateOrderLots();
    int ticket = OrderSend(Symbol(), OP_BUY, lotToUse, Ask, Slippage, NormalizeDouble((Ichimoku_SL_value),Digits()), NormalizeDouble(0,Digits()), Trade_Comment, Trade_Reference, 0, Green);

    if (ticket > 0)
    {
        Print("Long Sleep Well opened : ", OrderOpenPrice());
        FREEDOM = true;
        IsNewM1Candle = false;
        lastTradeOpenTime = TimeCurrent();
    }
    else
    {
      Print("Cannot open long positiona : ", GetLastError());
      FREEDOM = false;
    }
  
  }

  return FREEDOM;
 } 
  
  double Ichimoku_SL_BUY(){
  
  double atrSL = iATR(NULL,PERIOD_M1,4,1);
  
  double below_Candle_SL = Bid - (ATR_SL*atrSL);
  double check = Bid - (Max_SL*Point());
   
  if(below_Candle_SL > 0 && below_Candle_SL > check){
      return below_Candle_SL;
     }else{
      return check;
      }      
  return 0;
}

bool canOpen_Spread()
{
  bool result = true;
  int spread_value = MarketInfo(NULL,MODE_SPREAD);                                     
  if(spread_value > Max_Spread) {
        result = false;
   }  
  return result;
}
 
 
bool isFastLong_RSI() {

          
      double atrSL = iATR(NULL,PERIOD_M1,4,1);
      double atrM15 = iATR(NULL,PERIOD_M15,14,0);
      double M1_RatioATR5 = iATR(NULL,PERIOD_M1,5,0);
      double M1_RatioATR14 = iATR(NULL,PERIOD_M1,14,0);
      double M15_RatioATR5 = iATR(NULL,PERIOD_M15,5,1);
      double M15_RatioATR14 = iATR(NULL,PERIOD_M15,14,1);
      
      double LastLowM15 =  iLow(NULL,PERIOD_M15, 1); 
      double LastHighM15 =  iHigh(NULL,PERIOD_M15, 1);
                 
      double LastOpen =  iOpen(NULL, PERIOD_M1, 0); 
      double PrevHigh =  iHigh(NULL, PERIOD_M1, 1);
      double PrevLow =  iLow(NULL, PERIOD_M1, 1); 
      double currentM1Open = iOpen(NULL,PERIOD_M1,0);  
            

       bool openBy5MasSignal = false;
       double Current_M1_Close =  NormalizeDouble((Bid+Ask)/2, Digits());
     
         
     if(speedTickPrev5Sec * SpeedIncreased < speedTick5Sec && speedTick15Sec > MINspeed15sec && amountOfTrades < 1 && (!use_ATR_size || (ATR_min_size < atrSL && ATR_max_size > atrSL)) && (avgTickSpaceValue > avgTickSpace) && (MathAbs(avgTickSpace - fastTickSpace)<DeviationTickDelta) && (!RatioATRCheck || M1_RatioATR5/M1_RatioATR14 > M1_ATR5vsATR14) && (!RatioATRCheck || M15_RatioATR5/M15_RatioATR14 > M15_ATR5vsATR14)){
    
           if (currentM1Open != lastM1Open)
           {
            lastM1Open = currentM1Open;
            IsNewM1Candle = true;
           }   
              
       if(CanOpen && (!OneCandleOnly || IsNewM1Candle) && (upRatio - 0.1 < TickThreshold)){
       
  
            if(upRatio > TickThreshold && ((LastHighM15+0.1*atrM15) > currentM1Open && (LastLowM15-0.1*atrM15) < currentM1Open)){                                     

                    openBy5MasSignal = true;
                    return openBy5MasSignal;
                          
            }                                             
      }
    
     }
    return openBy5MasSignal;
  } 
 
bool isFastShort_RSI() {

          
      double atrSL = iATR(NULL,PERIOD_M1,4,1);
      double atrM15 = iATR(NULL,PERIOD_M15,14,0);
      double M1_RatioATR5 = iATR(NULL,PERIOD_M1,5,0);
      double M1_RatioATR14 = iATR(NULL,PERIOD_M1,14,0);
      double M15_RatioATR5 = iATR(NULL,PERIOD_M15,5,1);
      double M15_RatioATR14 = iATR(NULL,PERIOD_M15,14,1);
      
      double LastLowM15 =  iLow(NULL,PERIOD_M15, 1); 
      double LastHighM15 =  iHigh(NULL,PERIOD_M15, 1);
            
      double LastOpen =  iOpen(NULL, PERIOD_M1, 0);
      double PrevHigh =  iHigh(NULL, PERIOD_M1, 1);
      double PrevLow =  iLow(NULL, PERIOD_M1, 1); 
      double currentM1Open = iOpen(NULL,PERIOD_M1,0);    
            

       bool openBy5MasSignal = false;
       double Current_M1_Close =  NormalizeDouble((Bid+Ask)/2, Digits()); 
      
    
     if(speedTickPrev5Sec * SpeedIncreased < speedTick5Sec && speedTick15Sec > MINspeed15sec && amountOfTrades < 1 && (!use_ATR_size || (ATR_min_size < atrSL && ATR_max_size > atrSL)) && (avgTickSpaceValue > avgTickSpace) && (MathAbs(avgTickSpace - fastTickSpace)<DeviationTickDelta) && (!RatioATRCheck || M1_RatioATR5/M1_RatioATR14 > M1_ATR5vsATR14) && (!RatioATRCheck || M15_RatioATR5/M15_RatioATR14 > M15_ATR5vsATR14)){
       
           if (currentM1Open != lastM1Open)
           {
            lastM1Open = currentM1Open;
            IsNewM1Candle = true;
           } 
           
        if(CanOpen && (!OneCandleOnly || IsNewM1Candle) && (downRatio - 0.1 < TickThreshold)){
        
  
            if(downRatio > TickThreshold && ((LastHighM15+0.1*atrM15) > currentM1Open && (LastLowM15-0.1*atrM15) < currentM1Open)){                                     

                    openBy5MasSignal = true;
                    return openBy5MasSignal;
                          
            }                                     
      }
    
     }
    return openBy5MasSignal;
  }
 
  
bool closeAllWolfsWithHG() {    
    int totalOpenOrders = OrdersTotal();   
    if (totalOpenOrders > 0){
         for(int cnt = 0; cnt < totalOpenOrders; cnt++) {
            if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
            {
               Print("Error during position close on select, ", GetLastError());
              // Print("Error closeAllWolfs on select, ", OrderPrint());
               continue;
            }
            int orderMagicNumber = OrderMagicNumber();
            if(orderMagicNumber == Trade_Reference){         
              if(OrderSymbol() == Symbol()) {
                   if(OrderType() == OP_SELL){                        
                      if (OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, Blue)){
                         Print("SELL closeAll," ,orderMagicNumber);
                      }else {
                         Print("Error closeAll, ", GetLastError());                        
                      } 
                   }
                   if(OrderType() == OP_BUY){                    
                       if (OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, Blue)){
                           Print("BUY closeAll,",orderMagicNumber);    
                       }else {                        
                            Print("Error closeAll, ", GetLastError());                        
                       }                      
                   }                                    
               }                          
           }
          
        }   
     }
    
    //check if close all wolf
    int totalOpenOrdersCheck = OrdersTotal();
    int wolfs =0;   
    if (totalOpenOrdersCheck > 0){
         for(int cnt = 0; cnt < totalOpenOrdersCheck; cnt++) {
            if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
            {
               Print("Error closeAll on select, ", GetLastError());
               continue;
            }
            if (OrderSymbol() == Symbol()){
            int orderMagicNumber = OrderMagicNumber();
            if(orderMagicNumber == Trade_Reference){
               wolfs++;
            }
            }
        }
    }
    return wolfs==0?true:false;        
}

double getCurrentOpenProfit()
{
    double currentProfitOnOpenTrades = 0.0;
    
    int total=OrdersTotal();  
    if (total > 0)
    {
        for (int cnt = 0; cnt < total; cnt++)
        {
            if (OrderSelect(cnt, SELECT_BY_POS,MODE_TRADES))
            {
                 double cleanProfit = NormalizeDouble(OrderProfit() - MathAbs(OrderCommission()) - MathAbs(OrderSwap()), Digits());
                 currentProfitOnOpenTrades += cleanProfit;              
            }

        }
    }
    return NormalizeDouble(currentProfitOnOpenTrades, Digits());
}


void modif_Buy() {
        
          
          int spread_value = MarketInfo(NULL,MODE_SPREAD);
          double atrSL = iATR(NULL,PERIOD_M1,4,1);
                    
          double SL_Trigger_Buy = NormalizeDouble((OrderOpenPrice()-OrderStopLoss()),Digits());
          double HalfTP_calc = NormalizeDouble((OrderTakeProfit() - OrderOpenPrice())/2,Digits());
          double HalfTP_SLcalc = NormalizeDouble((OrderOpenPrice() - HalfTP_calc),Digits());
          double PrevLow =  iLow(NULL, PERIOD_M1, 1);
  
              
          /////////////////////////////////////////////////////////////////////////////////////////////////
          double Current_value  =  NormalizeDouble((Bid + Ask)/2 ,Digits()); 
          double stopLoss = OrderStopLoss();
          double takeProfit = OrderTakeProfit();
         
                   
        
        if(OrderTakeProfit() == 0 && !TP_Dynamic){  
       
            takeProfit=NormalizeDouble(OrderOpenPrice() + atrSL*ATR_TP,Digits());       
          
         } 
        
        if(TP_Dynamic){  
       
            takeProfit=NormalizeDouble(OrderOpenPrice() + atrSL*ATR_TP,Digits());       
          
         } 
         
       if(!ConstSL){  
        if((!HalfTP_SL && OrderStopLoss() < OrderOpenPrice()) || Infinite_SL){ 
            stopLoss=NormalizeDouble(Bid - atrSL*ATR_SL,Digits());
          } 
             
        if(HalfTP_SL && OrderStopLoss() < HalfTP_SLcalc){ 
            stopLoss=NormalizeDouble(Bid - atrSL*ATR_SL,Digits());
          } 
 
       }
          /////////////////////////////////////////////////////////////////////////////////////////////////
         
          if(stopLoss - OrderStopLoss() > 10*Point() || OrderTakeProfit() == 0){
                   if (!OrderModify(OrderTicket(), OrderOpenPrice(), stopLoss, takeProfit, 0, Green))
                   {                                  
                    // return;
                   }
                   else
                   {   
  
                   //  return;
                   }          
            
           }
          if(TP_Dynamic && MathAbs(takeProfit - OrderTakeProfit()) > 10*Point()){
                   if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), takeProfit, 0, Green))
                   {                                  
                    // return;
                   }
                   else
                   {   
  
                   //  return;
                   }          
            
           }  
                 
    return;
}

void modif_Sell() {

           
          int spread_value = MarketInfo(NULL,MODE_SPREAD);
          double atrSL = iATR(NULL,PERIOD_M1,4,1);
                      
          double SL_Trigger_Sell = NormalizeDouble((OrderStopLoss()-OrderOpenPrice()),Digits());
          double HalfTP_calc = NormalizeDouble((OrderOpenPrice() - OrderTakeProfit())/2,Digits());
          double HalfTP_SLcalc = NormalizeDouble((OrderOpenPrice() + HalfTP_calc),Digits());
          double PrevHigh =  iHigh(NULL, PERIOD_M1, 1);
        
        
          //////////////////////////////////////////////////////////////////////////////////////////////// 
         
          double Current_value  =  NormalizeDouble((Bid + Ask)/2 ,Digits());       
          double stopLoss = OrderStopLoss();
          double takeProfit = OrderTakeProfit();

                           
         if(OrderTakeProfit()==0 && !TP_Dynamic){ 
        
             takeProfit=NormalizeDouble(OrderOpenPrice() - atrSL*ATR_TP,Digits()); 
                 
          } 
         
         if(TP_Dynamic){ 
        
             takeProfit=NormalizeDouble(OrderOpenPrice() - atrSL*ATR_TP,Digits()); 
                 
          }  
       
        if(!ConstSL){ 
         if((!HalfTP_SL && OrderStopLoss() > OrderOpenPrice()) || Infinite_SL){ 
             stopLoss=NormalizeDouble(Ask + atrSL*ATR_SL,Digits());
            
          }

         if(HalfTP_SL && OrderStopLoss() > HalfTP_SLcalc){ 
            stopLoss=NormalizeDouble(Ask + atrSL*ATR_SL,Digits());
          } 
        }

          ////////////////////////////////////////////////////////////////////////////////////////////////// 
          if(OrderStopLoss() - stopLoss > 10*Point() || OrderStopLoss() == 0 || OrderTakeProfit() == 0){
                   if (!OrderModify(OrderTicket(), OrderOpenPrice(), stopLoss, takeProfit, 0, Green))
                   {
                     return;
                   }
                   else
                   {
                   

                     return;
                   }          
            
         }  
          if(TP_Dynamic && MathAbs(OrderTakeProfit() - takeProfit) > 10*Point()){
                   if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), takeProfit, 0, Green))
                   {
                     return;
                   }
                   else
                   {
                   

                     return;
                   }          
            
         }       
    return;
  
}



void numberOfTotalTrades(){

int totalTrades = OrdersTotal();
    amountOfTrades = 0;

if(totalTrades != 0){

      for (int i = 0; i < totalTrades; i++)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if (OrderSymbol() == Symbol())
            {
               int magicNr = OrderMagicNumber();
               if (magicNr == Trade_Reference)
               {
               int valuePositive = 1;
                   amountOfTrades = amountOfTrades + valuePositive;
               }
            }
         }
      }
    //  Print("amountOfTrades: " + amountOfTrades);

   }
}

bool tradeBUYSecured(){

int totalTrades = OrdersTotal();
bool BUY_secured = false;

if(totalTrades != 0){

      for (int i = 0; i < totalTrades; i++)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if (OrderSymbol() == Symbol())
            {
               int magicNr = OrderMagicNumber();
               if (magicNr == Trade_Reference)
               {
                  if (OrderType() == OP_BUY)
                  {
                     if(OrderOpenPrice() < OrderStopLoss()){
                     BUY_secured = true;
                     Print("BUY_secured: " + BUY_secured);
                     return BUY_secured;
                     }
                  }
               }
            }
         }
      }
    //  Print("amountOfTrades: " + amountOfTrades);

   }
   return BUY_secured;
}

bool tradeSELLecured(){

int totalTrades = OrdersTotal();
bool SELL_secured = false; 

if(totalTrades != 0){

      for (int i = 0; i < totalTrades; i++)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if (OrderSymbol() == Symbol())
            {
               int magicNr = OrderMagicNumber();
               if (magicNr == Trade_Reference)
               {
                  if (OrderType() == OP_SELL)
                  {
                     if(OrderOpenPrice() > OrderStopLoss()){
                     SELL_secured = true;
                     Print("SELL_secured: " + SELL_secured);
                     return SELL_secured;
                     }
                  }
               }
            }
         }
      }
    //  Print("amountOfTrades: " + amountOfTrades);

   }
   return SELL_secured;
}


// Function to update the buffer and calculate avgTickSpace
void UpdateAveragePriceChange(double newPrice)
{
    // Update the circular buffer
    priceBuffer[bufferIndex] = newPrice;
    bufferIndex = (bufferIndex + 1) % PriceBufforSize; // Move to the next index
    if (bufferCount < PriceBufforSize) 
        bufferCount++; // Increment buffer count up to the limit

    // Calculate average price change if we have enough data
    if (bufferCount > 1)
    {
        double totalChange = 0;
        for (int i = 1; i < bufferCount; i++)
        {
            int currentIndex = (bufferIndex - i + PriceBufforSize) % PriceBufforSize;
            int previousIndex = (currentIndex - 1 + PriceBufforSize) % PriceBufforSize;
            totalChange += MathAbs(priceBuffer[currentIndex] - priceBuffer[previousIndex]);
        }
        avgTickSpace = totalChange / (bufferCount - 1);
    }
}

// Function to update the buffer and calculate fastTickSpace
void UpdateDeviation(double newPrice)
{
    // Update the circular buffer
    priceBufferFast[bufferIndexFast] = newPrice;
    bufferIndexFast = (bufferIndexFast + 1) % PriceBufforSizeFast;

    if (bufferCountFast < PriceBufforSizeFast)
        bufferCountFast++;

    // Calculate standard deviation if enough data
    if (bufferCountFast > 1)
    {
        double sum = 0;
        double sumSq = 0;

        // Obliczamy sumę i sumę kwadratów
        for (int i = 0; i < bufferCountFast; i++)
        {
            int index = (bufferIndexFast - i - 1 + PriceBufforSizeFast) % PriceBufforSizeFast;
            double price = priceBufferFast[index];
            sum += price;
            sumSq += price * price;
        }

        double mean = sum / bufferCountFast;
        double variance = (sumSq / bufferCountFast) - (mean * mean);

        if (variance < 0) variance = 0; // zabezpieczenie przed błędami zaokrągleń

        fastTickSpace = MathSqrt(variance);
    }
}

void UpdateTickSpeeds()
{
    datetime now = TimeCurrent(); // Aktualny czas serwera

    // Dodaj nowy tick timestamp do bufora cyklicznego
    tickTimeBuffer[tickBufferIndex] = now;
    tickBufferIndex = (tickBufferIndex + 1) % TickBufforSize;
    if (tickBufferCount < TickBufforSize)
        tickBufferCount++;

    // Liczniki do różnych przedziałów czasowych
    double count15Sec = 0;
    double count5Sec = 0;
    double countPrev5Sec = 0;

    for (int i = 0; i < tickBufferCount; i++)
    {
        int index = (tickBufferIndex - i - 1 + TickBufforSize) % TickBufforSize;
        int secondsAgo = now - tickTimeBuffer[index];

        if (secondsAgo <= 15)
            count15Sec++;
        if (secondsAgo <= 5)
            count5Sec++;
        else if (secondsAgo > 5 && secondsAgo <= 10)
            countPrev5Sec++;
        
        // Jeśli tick jest starszy niż 15 minut, nie ma sensu dalej liczyć
        if (secondsAgo > 15)
            break;
    }

    // Aktualizujemy zmienne
    speedTick15Sec = count15Sec/15;
    speedTick5Sec = count5Sec/5;
    speedTickPrev5Sec = countPrev5Sec/5;
}

void UpDownRatio() {

   double currentPrice = Bid;

   // Przesuwanie bufora
   for (int i = LastTickNumber - 1; i > 0; i--)
   {
      tickBuffer[i] = tickBuffer[i - 1];
   }
   tickBuffer[0] = currentPrice;

   if (bufferSize < LastTickNumber)
   {
      bufferSize++;
      return;
   }

   int upMoves = 0;
   int downMoves = 0;

   for (int i = 0; i < LastTickNumber - 1; i++)
   {
      if (tickBuffer[i] > tickBuffer[i + 1])
         upMoves++;
      else if (tickBuffer[i] < tickBuffer[i + 1])
         downMoves++;
   }

   double total = upMoves + downMoves;

   if (total == 0) return;

   upRatio = upMoves / total;
   downRatio = downMoves / total;

} 
