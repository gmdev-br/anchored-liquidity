//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© GM, 2021, 2022, 2023"
#property description "Anchored Liquidity Levels"
#property strict
#property indicator_chart_window
#property indicator_plots 0
#property indicator_buffers 0

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_REG_SOURCE {
   Open,           // Open
   High,           // High
   Low,             // Low
   Close,         // Close
   Typical,     // Typical
   Variation     // Variation
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input group "***************  GERAL ***************"
input datetime                   DefaultInitialDate              = "2023.5.31 09:00:00";          // Data inicial padrão
input datetime                   DefaultFinalDate                = -1;                             // Data final padrão
input int                        WaitMilliseconds                = 30000;                          // Timer (milliseconds) for recalculation
input bool                       EnableEvents                    = false;                          // Ativa os eventos de teclado

input bool     shortMode = true;
input int      shortStart = 8;
input int      shortEnd = 10;
input bool     enableD = true;
input bool     enableW = false;
input bool     enableMN = false;

input group "***************  DELIMITADORES ***************"
input string                     Id                              = "+rlh";                         // IDENTIFICADOR
input string                     inputAtivo                      = "";                             // ATIVO
input color                      TimeFromColor                   = clrLime;                        // ESQUERDO: cor
input int                        TimeFromWidth                   = 1;                              // ESQUERDO: largura
input ENUM_LINE_STYLE            TimeFromStyle                   = STYLE_DASH;                     // ESQUERDO: estilo
input color                      TimeToColor                     = clrRed;                         // DIREITO: cor
input int                        TimeToWidth                     = 1;                              // DIREITO: largura
input ENUM_LINE_STYLE            TimeToStyle                     = STYLE_DASH;                     // DIREITO: estilo
//input bool                       AutoLimitLines                  = true;                           // Automatic limit left and right lines
input bool                       FitToLines                      = true;                           // Automatic fit histogram inside lines
input bool                       KeepRightLineUpdated            = true;                           // Automatic update of the rightmost line
input int                        ShiftCandles                    = 6;                              // Distance in candles to adjust on automatic
input bool                       useHL = false;
input bool                       drawMain = false;
input bool                       draw15 = true;
input bool debug = false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int totalRates;
int DigitsM;                        // Number of digits normalized based on HistogramPointScale_calculated.

datetime data_inicial;         // Data inicial para mostrar as linhas
datetime data_final;         // Data final para mostrar as linhas
datetime timeFrom;
datetime timeTo;
datetime minimumDate;
datetime maximumDate;
datetime timeHigh[], startTop[], startBottom[], breakHigh[], breakLow[];

int barFrom, barTo;
int indiceFinal, indiceInicial;

double A, B, stdev;

long totalCandles = 0;
bool onlyRedraw = false;
bool calculating = false;

datetime       arrayTime[];
double         arrayOpen[], arrayHigh[], arrayLow[], arrayClose[], tempTop[], tempBottom[], targetTop[], targetBottom[];
string ativo;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {

   _timeFromLine = Id + "-from";
   _timeToLine = Id + "-to";

   if (inputAtivo != "")
      ativo = inputAtivo;

   data_inicial = DefaultInitialDate;
   if (KeepRightLineUpdated && ((DefaultFinalDate == -1) || (DefaultFinalDate > iTime(ativo, PERIOD_CURRENT, 0))))
      data_final = iTime(ativo, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * ShiftCandles;

   _timeToColor = TimeToColor;
   _timeFromColor = TimeFromColor;
   _timeToWidth = TimeToWidth;
   _timeFromWidth = TimeFromWidth;

   _lastOK = false;
   _updateTimer = new MillisecondTimer(WaitMilliseconds, false);
   EventSetMillisecondTimer(WaitMilliseconds);

   ObjectsDeleteAll(0, "liq_dn_");

   ChartRedraw();

//iATR_handle = iATR(ativo, PERIOD_CURRENT, 5000);

   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void verifyDates() {

   minimumDate = iTime(ativo, PERIOD_CURRENT, iBars(ativo, PERIOD_CURRENT) - 2);
   maximumDate = iTime(ativo, PERIOD_CURRENT, 0);

   timeFrom = GetObjectTime1(_timeFromLine);
   timeTo = GetObjectTime1(_timeToLine);

   data_inicial = DefaultInitialDate;
   data_final = DefaultFinalDate;
   if (KeepRightLineUpdated && ((DefaultFinalDate == -1) || (DefaultFinalDate > iTime(ativo, PERIOD_CURRENT, 0))))
      data_final = iTime(ativo, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * ShiftCandles;

   if ((timeFrom == 0) || (timeTo == 0)) {
      timeFrom = data_inicial;
      timeTo = data_final;
      DrawVLine(_timeFromLine, timeFrom, _timeFromColor, _timeFromWidth, TimeFromStyle, true, false, true, 1000);
      DrawVLine(_timeToLine, timeTo, _timeToColor, _timeToWidth, TimeToStyle, true, false, true, 1000);
   }

   if (ObjectGetInteger(0, _timeFromLine, OBJPROP_SELECTED) == false) {
      timeFrom = data_inicial;
   }

   if (ObjectGetInteger(0, _timeToLine, OBJPROP_SELECTED) == false) {
      timeTo = data_final;
   }

   if ((timeFrom < minimumDate) || (timeFrom > maximumDate))
      timeFrom = minimumDate;

   if ((timeTo >= maximumDate) || (timeTo < minimumDate))
      timeTo = maximumDate + PeriodSeconds(PERIOD_CURRENT) * ShiftCandles;

   ObjectSetInteger(0, _timeFromLine, OBJPROP_TIME, 0, timeFrom);
   ObjectSetInteger(0, _timeToLine, OBJPROP_TIME, 0, timeTo);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[]) {
   return(1);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer() {
   CheckTimer();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {

   if(UninitializeReason() == REASON_REMOVE) {
      ObjectDelete(0, _timeFromLine);
      ObjectDelete(0, _timeToLine);
   }

   ObjectsDeleteAll(0, "liq_up_");
   ObjectsDeleteAll(0, "liq_dn_");

   ObjectsDeleteAll(0, "liq_proj_up");
   ObjectsDeleteAll(0, "liq_proj_dn");

   delete(_updateTimer);
   ChartRedraw();

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckTimer() {
   EventKillTimer();

   if(_updateTimer.Check() || !_lastOK) {
      if (enableD) _lastOK = Update(PERIOD_D1, 2);
      if (enableW) _lastOK = Update(PERIOD_W1, 5);
      if (enableMN) _lastOK = Update(PERIOD_MN1, 10);
      if (debug) Print("Anchored Liquidity " + " " + ativo + ":" + GetTimeFrame(Period()) + " ok");

      EventSetMillisecondTimer(WaitMilliseconds);

      _updateTimer.Reset();
   } else {
      EventSetTimer(1);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Update(ENUM_TIMEFRAMES p_tf, int str, int offset = 0) {

   string tf_name = GetTimeFrame(p_tf);
   string liq_up = "liq_up_" + tf_name + "_";
   string liq_dn = "liq_dn_" + tf_name + "_";

   string proj_up1 = "liq_proj_up1_" + tf_name + "_";
   string proj_up2 = "liq_proj_up2_" + tf_name + "_";

   string proj_dn1 = "liq_proj_dn1_" + tf_name + "_";
   string proj_dn2 = "liq_proj_dn2_" + tf_name + "_";

   ObjectsDeleteAll(0, liq_up);
   ObjectsDeleteAll(0, liq_dn);

   ObjectsDeleteAll(0, proj_up1);
   ObjectsDeleteAll(0, proj_up2);
   ObjectsDeleteAll(0, proj_dn1);
   ObjectsDeleteAll(0, proj_dn2);

   verifyDates();

   barFrom = iBarShift(NULL, p_tf, timeFrom);
   barTo = iBarShift(NULL, p_tf, timeTo);

   totalRates = SeriesInfoInteger(ativo, p_tf, SERIES_BARS_COUNT);

   int tempVar = CopyTime(ativo, p_tf, 0, totalRates, arrayTime);
   tempVar = CopyClose(ativo, p_tf, 0, totalRates, arrayClose);
   tempVar = CopyHigh(ativo, p_tf, 0, totalRates, arrayHigh);

   tempVar = CopyOpen(ativo, p_tf, 0, totalRates, arrayOpen);
   tempVar = CopyLow(ativo, p_tf, 0, totalRates, arrayLow);

//ArrayReverse(targetBottom);
//ArrayReverse(arrayClose);
//ArrayReverse(targetTop);
//ArrayReverse(arrayOpen);

   ArraySetAsSeries(arrayOpen, true);
   ArraySetAsSeries(arrayHigh, true);
   ArraySetAsSeries(arrayClose, true);
   ArraySetAsSeries(arrayLow, true);
   ArraySetAsSeries(arrayTime, true);
   ArraySetAsSeries(targetTop, true);
   ArraySetAsSeries(targetBottom, true);

   ArrayResize(tempTop, ArraySize(arrayHigh));
   ArrayInitialize(tempTop, 0);
   ArrayResize(tempBottom, ArraySize(arrayLow));
   ArrayInitialize(tempBottom, 0);
   ArrayResize(targetBottom, ArraySize(arrayLow));
   ArrayInitialize(targetBottom, 0);
   ArrayResize(targetTop, ArraySize(arrayHigh));
   ArrayInitialize(targetBottom, 0);

   ArrayResize(timeHigh, ArraySize(arrayHigh));
   ArrayInitialize(timeHigh, 0);
   ArrayResize(startBottom, ArraySize(arrayLow));
   ArrayInitialize(startBottom, 0);
   ArrayResize(startTop, ArraySize(arrayHigh));
   ArrayInitialize(startTop, 0);
   ArrayResize(breakLow, ArraySize(arrayLow));
   ArrayInitialize(breakLow, 0);
   ArrayResize(breakHigh, ArraySize(arrayHigh));
   ArrayInitialize(breakHigh, 0);

   ObjectSetInteger(0, _timeFromLine, OBJPROP_TIME, 0, timeFrom);
   ObjectSetInteger(0, _timeToLine, OBJPROP_TIME, 0, timeTo);

   if(timeFrom > timeTo)
      Swap(timeFrom, timeTo);

   _updateOnTick = barTo < 0;

   int primeiroCandle = WindowFirstVisibleBar();
   int ultimoCandle = WindowFirstVisibleBar() - WindowBarsPerChart();
   int lineFromPosition = 0, lineToPosition = 0;
   if (FitToLines == true) {
      lineFromPosition = iBarShift(ativo, PERIOD_CURRENT, GetObjectTime1(_timeFromLine), 0);
      lineToPosition = iBarShift(ativo, PERIOD_CURRENT, GetObjectTime1(_timeToLine), 0);
   }

   for(int i = barTo < 0 ? 0 : barTo; i <= barFrom ; i++) {
      targetTop[i] = useHL ? arrayHigh[i] : arrayClose[i] >= arrayOpen[i] ? arrayClose[i] : arrayOpen[i];
      targetBottom[i] = useHL ? arrayLow[i] : arrayClose[i] >= arrayOpen[i] ? arrayOpen[i] : arrayClose[i];
      tempTop[i] = useHL ? arrayHigh[i] : arrayClose[i] >= arrayOpen[i] ? arrayClose[i] : arrayOpen[i];
      tempBottom[i] = useHL ? arrayLow[i] : arrayClose[i] >= arrayOpen[i] ? arrayOpen[i] : arrayClose[i];
      startBottom[i] = iTime(NULL, p_tf, i);
      startTop[i] = iTime(NULL, p_tf, i);
   }

//   datetime periodStart = iTime(NULL, PERIOD_MN1, 1);
//   for(int i = barFrom; i > (barTo < 0 ? 0 : barTo); i--) {
//      for(int j = i - 1; j > (barTo < 0 ? 0 : barTo); j--) {
//         //if (tempTop[i] <= arrayHigh[j])
//         //   tempTop[i] = 0;
//         //if (periodStart > arrayTime[i] && tempTop[i] <= arrayHigh[j])
//         //   tempTop[i] = -1;
//         if (arrayHigh[j] >= tempTop[i] && breakHigh[i] == 0) {
//            tempTop[i] = 0;
//            //tempBottom[i] = 0;
//            breakHigh[i] = iTime(NULL, p_tf, j);
//         }
//
//         if (arrayLow[j] <= tempTop[i] && breakLow[i] == 0) {
//            tempTop[i] = 0;
//            //tempBottom[i] = 0;
//            breakLow[i] = iTime(NULL, p_tf, j);
//         }
//
//         if (arrayLow[j] <= tempBottom[i] && breakLow[i] == 0) {
//            //tempTop[i] = 0;
//            tempBottom[i] = 0;
//            breakLow[i] = iTime(NULL, p_tf, j);
//         }
//
//         //if (periodStart > startBottom[i] && tempBottom[i] >= arrayLow[j])
//         //   tempBottom[i] = -1;
//      }
//   }

//for(int i = barTo < 0 ? 0 : barTo; i < barFrom ; i++) {
//   if (tempTop[i] < 0)
//      continue;
//   ObjectCreate(0, "teste_high_" + i, OBJ_TREND, 0, iTime(NULL, p_tf, i), arrayHigh[i], timeTo, arrayHigh[i]);
//   if (tempTop[i] == 0)
//      ObjectSetInteger(0, "teste_high_" + i, OBJPROP_COLOR, clrDimGray);
//   else if (tempTop[i] > 0)
//      ObjectSetInteger(0, "teste_high_" + i, OBJPROP_COLOR, clrRed);
//}
   bool upCandle;
   string valor;
   for(int i = barTo < 0 ? 0 : barTo; i <= barFrom ; i++) {

      datetime start_time = shortMode ? iTime(ativo, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * shortStart : iTime(NULL, p_tf, i);
      datetime end_time = shortMode ? iTime(ativo, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * (shortEnd + offset) : iTime(NULL, p_tf, i);
      upCandle = arrayClose[i] >= arrayOpen[i] ? true : false;

      if (tempTop[i] > 0) {
         if (drawMain) {
            ObjectCreate(0, liq_up + i, OBJ_TREND, 0, start_time, targetTop[i], end_time, targetTop[i]);
            valor = "Top" +
                    "\nStart:" + startTop[i] +
                    "\nBreak:" + (breakHigh[i] > 0 ? breakHigh[i] : "-") +
                    "\nPrice:" + DoubleToString(targetTop[i], _Digits);
            ObjectSetString(0, liq_up + i, OBJPROP_TOOLTIP, valor);
            ObjectSetInteger(0, liq_up + i, OBJPROP_COLOR, upCandle ? clrLime : clrRed);
            ObjectSetInteger(0, liq_up + i, OBJPROP_WIDTH, str);
         }

         if (draw15) {
            if (upCandle)
               ObjectCreate(0, proj_up1 + i, OBJ_TREND, 0, start_time, targetTop[i] + 0.15 / 100 * targetTop[i], end_time, targetTop[i] + 0.15 / 100 * targetTop[i]);
            else
               ObjectCreate(0, proj_up1 + i, OBJ_TREND, 0, start_time, targetTop[i] - 0.15 / 100 * targetTop[i], end_time, targetTop[i] - 0.15 / 100 * targetTop[i]);

            valor = "Projection Top" +
                    "\nStart:" + startTop[i] +
                    "\nBreak:" + (breakHigh[i] > 0 ? breakHigh[i] : "-") +
                    "\nPrice:" + DoubleToString(upCandle ? targetTop[i] + 0.15 / 100 * targetTop[i] : targetTop[i] - 0.15 / 100 * targetTop[i], _Digits);
            ObjectSetString(0, proj_up1 + i, OBJPROP_TOOLTIP, valor);
            ObjectSetInteger(0, proj_up1 + i, OBJPROP_COLOR, upCandle ? clrLime : clrRed);
            ObjectSetInteger(0, proj_up1 + i, OBJPROP_WIDTH, str);
            ObjectSetInteger(0, proj_up1 + i, OBJPROP_STYLE, STYLE_DASH);

            //ObjectCreate(0, proj_up2 + i, OBJ_TREND, 0, start_time, targetTop[i] - 0.15 / 100 * targetTop[i], end_time, targetTop[i] - 0.15 / 100 * targetTop[i]);
            //valor = "Start:" + startTop[i] +
            //        "\nBreak:" + (breakHigh[i] > 0 ? breakHigh[i] : "-") +
            //        "\nPrice:" + tempTop[i];
            //ObjectSetString(0, proj_up2 + i, OBJPROP_TOOLTIP, valor);
            //ObjectSetInteger(0, proj_up2 + i, OBJPROP_COLOR, upCandle ? clrLime : clrRed);
            //ObjectSetInteger(0, proj_up2 + i, OBJPROP_WIDTH, str);
         }

      }
//      if (tempTop[i] == 0 && periodStart <= startTop[i]) {
//         ObjectCreate(0, liq_up + i, OBJ_TREND, 0, start_time, targetTop[i], end_time, targetTop[i]);
//         valor = "Start:" + startTop[i] +
//                 "\nBreak:" + (breakHigh[i] > 0 ? breakHigh[i] : "-") +
//                 "\nPrice:" + tempTop[i];
//         ObjectSetString(0, liq_up + i, OBJPROP_TOOLTIP, valor);
//         ObjectSetInteger(0, liq_up + i, OBJPROP_COLOR, upCandle ? C'0,80,0' : C'100,0,0');
//         ObjectSetInteger(0, liq_up + i, OBJPROP_WIDTH, str);
//
//         if (draw15) {
//            if (upCandle)
//               ObjectCreate(0, proj_up1 + i, OBJ_TREND, 0, start_time, targetTop[i] + 0.15 / 100 * targetTop[i], end_time, targetTop[i] + 0.15 / 100 * targetTop[i]);
//            else
//               ObjectCreate(0, proj_up1 + i, OBJ_TREND, 0, start_time, targetTop[i] - 0.15 / 100 * targetTop[i], end_time, targetTop[i] - 0.15 / 100 * targetTop[i]);
//
//            valor = "Start:" + startTop[i] +
//                    "\nBreak:" + (breakHigh[i] > 0 ? breakHigh[i] : "-") +
//                    "\nPrice:" + tempTop[i];
//            ObjectSetString(0, proj_up1 + i, OBJPROP_TOOLTIP, valor);
//            ObjectSetInteger(0, proj_up1 + i, OBJPROP_COLOR, upCandle ? C'0,80,0' : C'100,0,0');
//            ObjectSetInteger(0, proj_up1 + i, OBJPROP_WIDTH, 1);
//            ObjectSetInteger(0, proj_up1 + i, OBJPROP_STYLE, STYLE_DOT);
//
//            //ObjectCreate(0, proj_up2 + i, OBJ_TREND, 0, start_time, targetTop[i] - 0.15 / 100 * targetTop[i], end_time, targetTop[i] - 0.15 / 100 * targetTop[i]);
//            //valor = "Start:" + startTop[i] +
//            //        "\nBreak:" + (breakHigh[i] > 0 ? breakHigh[i] : "-") +
//            //        "\nPrice:" + tempTop[i];
//            //ObjectSetString(0, proj_up2 + i, OBJPROP_TOOLTIP, valor);
//            //ObjectSetInteger(0, proj_up2 + i, OBJPROP_COLOR, upCandle ? C'0,80,0' : C'100,0,0');
//            //ObjectSetInteger(0, proj_up2 + i, OBJPROP_WIDTH, str);
//         }
//      }
      //   ObjectSetInteger(0, "teste_low_" + i, OBJPROP_COLOR, clrDimGray);

      //if (periodStart >= breakLow[i] && breakLow[i] > 0)
      //   ObjectSetInteger(0, "teste_low_" + i, OBJPROP_COLOR, clrBlack);
      //if (periodStart < breakLow[i] && breakLow[i] > 0)
      //ObjectSetInteger(0, "teste_low_" + i, OBJPROP_COLOR, clrDimGray);
   }

   for(int i = barTo < 0 ? 0 : barTo; i <= barFrom ; i++) {

      datetime start_time = shortMode ? iTime(ativo, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * shortStart : iTime(NULL, p_tf, i);
      datetime end_time = shortMode ? iTime(ativo, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * (shortEnd + offset) : iTime(NULL, p_tf, i);
      upCandle = arrayClose[i] >= arrayOpen[i] ? true : false;

      if (tempBottom[i] > 0) {
         if (drawMain) {
            ObjectCreate(0, liq_dn + i, OBJ_TREND, 0, start_time, targetBottom[i], end_time, targetBottom[i]);
            valor = "Bottom" +
                    "\nStart:" + startBottom[i] +
                    "\nBreak:" + (breakLow[i] > 0 ? breakLow[i] : "-") +
                    "\nPrice:" + DoubleToString(tempBottom[i], _Digits);
            ObjectSetString(0, liq_dn + i, OBJPROP_TOOLTIP, valor);
            ObjectSetInteger(0, liq_dn + i, OBJPROP_COLOR, upCandle ? clrLime : clrRed);
            ObjectSetInteger(0, liq_dn + i, OBJPROP_WIDTH, str);
         }

         if (draw15) {
            if (upCandle)
               ObjectCreate(0, proj_dn1 + i, OBJ_TREND, 0, start_time, targetBottom[i] + 0.15 / 100 * targetBottom[i], end_time, targetBottom[i] + 0.15 / 100 * targetBottom[i]);
            else
               ObjectCreate(0, proj_dn1 + i, OBJ_TREND, 0, start_time, targetBottom[i] - 0.15 / 100 * targetBottom[i], end_time, targetBottom[i] - 0.15 / 100 * targetBottom[i]);

            valor = "Projection Bottom" +
                    "\nStart:" + startBottom[i] +
                    "\nBreak:" + (breakLow[i] > 0 ? breakLow[i] : "-") +
                    "\nPrice:" + DoubleToString((upCandle ? targetBottom[i] + 0.15 / 100 * targetBottom[i] : targetBottom[i] - 0.15 / 100 * targetBottom[i]), _Digits);
            ObjectSetString(0, proj_dn1 + i, OBJPROP_TOOLTIP, valor);
            ObjectSetInteger(0, proj_dn1 + i, OBJPROP_COLOR, upCandle ? clrLime : clrRed);
            ObjectSetInteger(0, proj_dn1 + i, OBJPROP_WIDTH, str);
            ObjectSetInteger(0, proj_dn1 + i, OBJPROP_STYLE, STYLE_DASH);

            //ObjectCreate(0, proj_dn2 + i, OBJ_TREND, 0, start_time, targetBottom[i] - 0.15 / 100 * targetBottom[i], end_time, targetBottom[i] - 0.15 / 100 * targetBottom[i]);
            //valor = "Start:" + startBottom[i] +
            //               "\nBreak:" + (breakLow[i] > 0 ? breakLow[i] : "-") +
            //               "\nPrice:" + tempBottom[i];
            //ObjectSetString(0, proj_dn2 + i, OBJPROP_TOOLTIP, valor);
            //ObjectSetInteger(0, proj_dn2 + i, OBJPROP_COLOR, upCandle ? clrLime : clrRed);
            //ObjectSetInteger(0, proj_dn2 + i, OBJPROP_WIDTH, str);
         }
      }
//      if (tempBottom[i] == 0 && periodStart <= startBottom[i]) {
//         ObjectCreate(0, liq_dn + i, OBJ_TREND, 0, start_time, targetBottom[i], end_time, targetBottom[i]);
//         valor = "Start:" + startBottom[i] +
//                 "\nBreak:" + (breakLow[i] > 0 ? breakLow[i] : "-") +
//                 "\nPrice:" + tempBottom[i];
//         ObjectSetString(0, liq_dn + i, OBJPROP_TOOLTIP, valor);
//         ObjectSetInteger(0, liq_dn + i, OBJPROP_COLOR, upCandle ? C'0,80,0' : C'100,0,0');
//         ObjectSetInteger(0, liq_dn + i, OBJPROP_WIDTH, str);
//
//         if (draw15) {
//            if (upCandle)
//               ObjectCreate(0, proj_dn1 + i, OBJ_TREND, 0, start_time, targetBottom[i] + 0.15 / 100 * targetBottom[i], end_time, targetBottom[i] + 0.15 / 100 * targetBottom[i]);
//            else
//               ObjectCreate(0, proj_dn1 + i, OBJ_TREND, 0, start_time, targetBottom[i] - 0.15 / 100 * targetBottom[i], end_time, targetBottom[i] - 0.15 / 100 * targetBottom[i]);
//
//            valor = "Start:" + startBottom[i] +
//                    "\nBreak:" + (breakLow[i] > 0 ? breakLow[i] : "-") +
//                    "\nPrice:" + tempBottom[i];
//            ObjectSetString(0, proj_dn1 + i, OBJPROP_TOOLTIP, valor);
//            ObjectSetInteger(0, proj_dn1 + i, OBJPROP_COLOR, upCandle ? C'0,80,0' : C'100,0,0');
//            ObjectSetInteger(0, proj_dn1 + i, OBJPROP_WIDTH, 1);
//            ObjectSetInteger(0, proj_dn1 + i, OBJPROP_STYLE, STYLE_DOT);
//
//            //ObjectCreate(0, proj_dn2 + i, OBJ_TREND, 0, start_time, targetBottom[i] - 0.15 / 100 * targetBottom[i], end_time, targetBottom[i] - 0.15 / 100 * targetBottom[i]);
//            //valor = "Start:" + startBottom[i] +
//            //               "\nBreak:" + (breakLow[i] > 0 ? breakLow[i] : "-") +
//            //               "\nPrice:" + tempBottom[i];
//            //ObjectSetString(0, proj_dn2 + i, OBJPROP_TOOLTIP, valor);
//            //ObjectSetInteger(0, proj_dn2 + i, OBJPROP_COLOR, upCandle ? C'0,80,0' : C'100,0,0');
//            //ObjectSetInteger(0, proj_dn2 + i, OBJPROP_WIDTH, str);
//         }
//      }
//   ObjectSetInteger(0, "teste_low_" + i, OBJPROP_COLOR, clrDimGray);

//if (periodStart >= breakLow[i] && breakLow[i] > 0)
//   ObjectSetInteger(0, "teste_low_" + i, OBJPROP_COLOR, clrBlack);
//if (periodStart < breakLow[i] && breakLow[i] > 0)
//ObjectSetInteger(0, "teste_low_" + i, OBJPROP_COLOR, clrDimGray);
   }
   ChartRedraw();

   return(true);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime GetObjectTime1(const string name) {
   datetime time;

   if(!ObjectGetInteger(0, name, OBJPROP_TIME, 0, time))
      return(0);

   return(time);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MathRound(const double value, const double error) {
   return(error == 0 ? value : MathRound(value / error) * error);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
template<typename T>
void Swap(T &value1, T &value2) {
   T tmp = value1;
   value1 = value2;
   value2 = tmp;

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime miTime(string symbol, ENUM_TIMEFRAMES timeframe, int index) {
   if(index < 0)
      return(-1);

   datetime arr[];

   if(CopyTime(symbol, timeframe, index, 1, arr) <= 0)
      return(-1);

   return(arr[0]);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int WindowBarsPerChart() {
   return((int)ChartGetInteger(0, CHART_WIDTH_IN_BARS));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int WindowFirstVisibleBar() {
   return((int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MillisecondTimer {

 private:
   int               _milliseconds;
 private:
   uint              _lastTick;

 public:
   void              MillisecondTimer(const int milliseconds, const bool reset = true) {
      _milliseconds = milliseconds;

      if(reset)
         Reset();
      else
         _lastTick = 0;
   }

 public:
   bool              Check() {
      uint now = getCurrentTick();
      bool stop = now >= _lastTick + _milliseconds;

      if(stop)
         _lastTick = now;

      return(stop);
   }

 public:
   void              Reset() {
      _lastTick = getCurrentTick();
   }

 private:
   uint              getCurrentTick() const {
      return(GetTickCount());
   }

};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawVLine(const string name, const datetime time1, const color lineColor, const int width, const int style, const bool back = true, const bool hidden = true, const bool selectable = true, const int zorder = 0) {
   ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_VLINE, 0, time1, 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, hidden);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, zorder);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#define KEY_RIGHT   68
#define KEY_LEFT  65

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {

   if(id == CHARTEVENT_OBJECT_DRAG) {
      if((sparam == _timeFromLine) || (sparam == _timeToLine)) {
         _lastOK = false;
         ChartRedraw();
         CheckTimer();
      }
   }
//
   if(id == CHARTEVENT_CHART_CHANGE && calculating == false) {
      _lastOK = true;
      CheckTimer();
      return;
   }

   static bool keyPressed = false;
   int barraLimite, barraNova, barraFrom, barraTo, primeiraBarraVisivel, ultimaBarraVisivel, ultimaBarraSerie;
   datetime tempoTimeFrom, tempoTimeTo, tempoBarra0, tempoUltimaBarraSerie;

   if(EnableEvents && id == CHARTEVENT_KEYDOWN) {
      if(lparam == KEY_RIGHT || lparam == KEY_LEFT) {
         if(!keyPressed)
            keyPressed = true;
         else
            keyPressed = false;

         // definição das variáveis comuns
         if ((ObjectGetInteger(0, _timeToLine, OBJPROP_SELECTED) == true) || (ObjectGetInteger(0, _timeFromLine, OBJPROP_SELECTED) == true)) {
            totalCandles = Bars(ativo, PERIOD_CURRENT);
            ultimaBarraSerie = totalCandles - 1;
            ultimaBarraVisivel = WindowFirstVisibleBar();
            barraFrom = iBarShift(ativo, PERIOD_CURRENT, ObjectGetInteger(0, _timeFromLine, OBJPROP_TIME));
            barraTo = iBarShift(ativo, PERIOD_CURRENT, ObjectGetInteger(0, _timeToLine, OBJPROP_TIME));
            tempoTimeFrom = GetObjectTime1(_timeFromLine);
            tempoTimeTo = GetObjectTime1(_timeToLine);
            tempoBarra0 = iTime(ativo, PERIOD_CURRENT, 0);

            tempoUltimaBarraSerie = iTime(ativo, PERIOD_CURRENT, totalCandles - 1);
         }
      }

      switch(int(lparam))  {
      case KEY_RIGHT: {
         if (ObjectGetInteger(0, _timeToLine, OBJPROP_SELECTED) == true) {
            if (barraFrom <= primeiraBarraVisivel)
               barraLimite = barraFrom;
            else
               barraLimite = primeiraBarraVisivel;

            EnableEvents == true ? barraNova = barraTo - 1 : barraNova = barraTo;
            if (barraNova >= 0) {
               datetime tempoNovo = iTime(ativo, PERIOD_CURRENT, barraNova);
               ObjectSetInteger(0, _timeToLine, OBJPROP_TIME, 0, tempoNovo);
               timeTo = tempoNovo;
               _lastOK = false;
               CheckTimer();
            } else if (barraNova < 0) {
               datetime tempoNovo = iTime(ativo, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT);
               ObjectSetInteger(0, _timeToLine, OBJPROP_TIME, 0, tempoNovo);
               timeTo = tempoNovo;
               _lastOK = false;
               CheckTimer();
            }
         }

         if (ObjectGetInteger(0, _timeFromLine, OBJPROP_SELECTED) == true) {
            barraLimite = 0;
            if (barraTo >= 0)
               barraLimite = barraTo;

            EnableEvents == true ? barraNova = barraTo - 1 : barraNova = barraTo;
            if (barraNova > barraLimite) {
               datetime tempoNovo = iTime(ativo, PERIOD_CURRENT, barraNova);
               ObjectSetInteger(0, _timeFromLine, OBJPROP_TIME, 0, tempoNovo);
               timeFrom = tempoNovo;
               _lastOK = false;
               CheckTimer();
            }
         }


      }
      break;

      case KEY_LEFT:  {
         if (ObjectGetInteger(0, _timeToLine, OBJPROP_SELECTED) == true) {
            barraTo = iBarShift(ativo, PERIOD_CURRENT, ObjectGetInteger(0, _timeToLine, OBJPROP_TIME));
            if (tempoTimeTo <= tempoUltimaBarraSerie) {
               barraNova = 0;
            } else {
               if (tempoTimeTo > tempoBarra0) {
                  barraNova = 0;
               } else {
                  EnableEvents == true ? barraNova = barraTo + 1 : barraNova = barraTo;
               }
            }

            datetime tempoNovo = iTime(ativo, PERIOD_CURRENT, barraNova);
            ObjectSetInteger(0, _timeToLine, OBJPROP_TIME, 0, tempoNovo);
            timeTo = tempoNovo;
            _lastOK = false;
            CheckTimer();
         }

         if (ObjectGetInteger(0, _timeFromLine, OBJPROP_SELECTED) == true) {
            if (tempoTimeFrom <= tempoUltimaBarraSerie)
               barraNova = barraFrom;
            else
               EnableEvents == true ? barraNova = barraFrom + 1 : barraNova = barraFrom;

            barraLimite = ultimaBarraSerie;

            if (barraNova < barraLimite) {
               datetime tempoNovo = iTime(ativo, PERIOD_CURRENT, barraNova);
               ObjectSetInteger(0, _timeFromLine, OBJPROP_TIME, 0, tempoNovo);
               timeFrom = tempoNovo;
               _lastOK = false;
               CheckTimer();
            }
         }
      }
      break;
      }
      return;

   }
}

//+---------------------------------------------------------------------+
//| GetTimeFrame function - returns the textual timeframe               |
//+---------------------------------------------------------------------+
string GetTimeFrame(int lPeriod) {
   switch(lPeriod) {
   case PERIOD_M1:
      return("M1");
   case PERIOD_M2:
      return("M2");
   case PERIOD_M3:
      return("M3");
   case PERIOD_M4:
      return("M4");
   case PERIOD_M5:
      return("M5");
   case PERIOD_M6:
      return("M6");
   case PERIOD_M10:
      return("M10");
   case PERIOD_M12:
      return("M12");
   case PERIOD_M15:
      return("M15");
   case PERIOD_M20:
      return("M20");
   case PERIOD_M30:
      return("M30");
   case PERIOD_H1:
      return("H1");
   case PERIOD_H2:
      return("H2");
   case PERIOD_H3:
      return("H3");
   case PERIOD_H4:
      return("H4");
   case PERIOD_H6:
      return("H6");
   case PERIOD_H8:
      return("H8");
   case PERIOD_H12:
      return("H12");
   case PERIOD_D1:
      return("D1");
   case PERIOD_W1:
      return("W1");
   case PERIOD_MN1:
      return("MN1");
   }
   return IntegerToString(lPeriod);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string _timeFromLine;
string _timeToLine;

bool _lastOK = false;

color _timeToColor;
color _timeFromColor;
int _timeToWidth;
int _timeFromWidth;

MillisecondTimer *_updateTimer;

bool _isTimeframeEnabled = false;

bool _updateOnTick = true;
ENUM_TIMEFRAMES _dataPeriod;
//+------------------------------------------------------------------+
