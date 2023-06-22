class DateConverter{
  static List<List<int>> nepali_years_and_days_in_months = [
    [2000, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2001, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2002, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2003, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2004, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2005, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2006, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2007, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2008, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    [2009, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2010, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2011, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2012, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    [2013, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2014, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2015, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2016, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    [2017, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2018, 31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2019, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2020, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    [2021, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2022, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    [2023, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2024, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    [2025, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2026, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2027, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2028, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2029, 31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
    [2030, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2031, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2032, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2033, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2034, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2035, 30, 32, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    [2036, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2037, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2038, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2039, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    [2040, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2041, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2042, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2043, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    [2044, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2045, 31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2046, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2047, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    [2048, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2049, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    [2050, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2051, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    [2052, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2053, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    [2054, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2055, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2056, 31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
    [2057, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2058, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2059, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2060, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2061, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2062, 30, 32, 31, 32, 31, 31, 29, 30, 29, 30, 29, 31],
    [2063, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2064, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2065, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2066, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    [2067, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2068, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2069, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2070, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    [2071, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2072, 31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    [2073, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    [2074, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    [2075, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2076, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    [2077, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    [2078, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    [2079, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    [2080, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    [2081, 31, 31, 32, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    [2082, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    [2083, 31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
    [2084, 31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
    [2085, 31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30],
    [2086, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    [2087, 31, 31, 32, 31, 31, 31, 30, 30, 29, 30, 30, 30],
    [2088, 30, 31, 32, 32, 30, 31, 30, 30, 29, 30, 30, 30],
    [2089, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
    [2090, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30]
  ];
  // Map<String, dynamic> days = {};
  // for (int i = 0; i < nepali_years_and_days_in_months.length; i++) {
  // int year = nepali_years_and_days_in_months[i][0];
  // days[year] = [];
  // for (int j = 0; j < 12; j++) {
  // days[year].add(nepali_years_and_days_in_months[i][j + 1]);
  // }
  // }


  static String getNepaliDayOfWeekInString(String day) {
    switch (day) {
      case "Sunday":
        return "आइतबार";
      case "Monday":
        return "सोमबार";
      case "Tuesday":
        return "मंगलबार";
      case "Wednesday":
        return "बुधबार";
      case "Thursday":
        return "बिहिबार";
      case "Friday":
        return "शुक्रबार";
      case "Saturday":
        return "शनिबार";
      default:
        return "Error Day";
    }
  }
 static String convertEnglishDateToNepali(int yy, int mm, int dd) {
   bool isSameDay(DateTime d1, DateTime d2) {
     if (d1 is DateTime && d2 is DateTime) {
       return (d1.year == d2.year) &&
           (d1.month == d2.month) &&
           (d1.day == d2.day);
     } else {
       return false;
     }
   }


   bool isLeapYear(int year) {
     if (year % 100 == 0) {
       return (year % 400 == 0);
     } else {
       return (year % 4 == 0);
     }
   }


   String getNepaliMonthInString(int month) {
     String nepaliMonth = "";

     switch (month) {
       case 1:
         nepaliMonth = "बैशाख";
         break;
       case 2:
         nepaliMonth = "जेष्ठ";
         break;
       case 3:
         nepaliMonth = "असार";
         break;
       case 4:
         nepaliMonth = "श्रावन";
         break;
       case 5:
         nepaliMonth = "भाद्र";
         break;
       case 6:
         nepaliMonth = "असोज";
         break;
       case 7:
         nepaliMonth = "कार्तिक";
         break;
       case 8:
         nepaliMonth = "मंसिर";
         break;
       case 9:
         nepaliMonth = "पौष";
         break;
       case 10:
         nepaliMonth = "माघ";
         break;
       case 11:
         nepaliMonth = "फाल्गुन";
         break;
       case 12:
         nepaliMonth = "चैत्र";
         break;
       default:
         nepaliMonth = "";
     }

     return nepaliMonth;
   }


   String getEnglishMonth(int month) {
     String englishMonth = "";

     switch (month) {
       case 1:
         englishMonth = "Baisakh";
         break;
       case 2:
         englishMonth = "Jesth";
         break;
       case 3:
         englishMonth = "Asar";
         break;
       case 4:
         englishMonth = "Srawan";
         break;
       case 5:
         englishMonth = "Bhadra";
         break;
       case 6:
         englishMonth = "Aaswin";
         break;
       case 7:
         englishMonth = "Kartik";
         break;
       case 8:
         englishMonth = "Mangsir";
         break;
       case 9:
         englishMonth = "Paush";
         break;
       case 10:
         englishMonth = "Magh";
         break;
       case 11:
         englishMonth = "Falgun";
         break;
       case 12:
         englishMonth = "Chaitra";
         break;
       default:
         englishMonth = "";
     }

     return englishMonth;
   }





   String getEnglishDayOfWeekInString(int day) {
     switch (day) {
       case 1:
         return "Sunday";
       case 2:
         return "Monday";
       case 3:
         return "Tuesday";
       case 4:
         return "Wednesday";
       case 5:
         return "Thursday";
       case 6:
         return "Friday";
       case 7:
         return "Saturday";
       default:
         return "";
     }
   }
   String zeroPad(int num, int places) {
     return num.toString().padLeft(places, '0');
   }


   bool checkIfDateIsInRange(int year, int month, int day) {
     if (year < 1944 || year > 2033) {
       return false;
     }
     if (month < 1 || month > 12) {
       return false;
     }
     return !(day < 1 || day > 31);
   }



   String addZero(int i) {
     if (i < 10) {
       return "0$i";
     }
     return i.toString();
   }
   bool isNumeric(n) {
     return n != null && double.tryParse(n.toString()) != null;
   }

   String englishToNepaliNumber(number) {
     switch (number) {
       case "0":
         number = "०";
         break;
       case "1":
         number = "१";
         break;
       case "2":
         number = "२";
         break;
       case "3":
         number = "३";
         break;
       case "4":
         number = "४";
         break;
       case "5":
         number = "५";
         break;
       case "6":
         number = "६";
         break;
       case "7":
         number = "७";
         break;
       case "8":
         number = "८";
         break;
       case "9":
         number = "९";
         break;
     }
     return number;
   }


   String localizeNumber(String temp) {
     for (int i = 0; i < temp.length; i++) {
       if (isNumeric(temp[i])) {
         temp = temp.replaceRange(i, i + 1, englishToNepaliNumber(temp[i]));
       }
     }
     return temp;
   }


   if (!checkIfDateIsInRange(yy, mm, dd)) {
  return "Invalid date !";
  }

  List<int> month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  List<int> leapYearMonths = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  int defEyy = 1944;
  int defNyy = 2000;
  int defNmm = 9;
  int defNdd = 17 - 1;
  int totalEDays = 0;

  int day = 7 - 1;
  int i, j;

  for (i = 0; i < (yy - defEyy); i++) {
  if (isLeapYear(defEyy + i)) {
  for (j = 0; j < 12; j++) {
  totalEDays += leapYearMonths[j];
  }
  } else {
  for (j = 0; j < 12; j++) {
  totalEDays += month[j];
  }
  }
  }

  for (i = 0; i < (mm - 1); i++) {
  if (isLeapYear(yy))
  totalEDays += leapYearMonths[i];
  else
  totalEDays += month[i];
  }

  totalEDays += dd;

  i = 0;
  j = defNmm;
  int totalNDays = defNdd;
  int m = defNmm;
  int y = defNyy;
  int a = 0;

  while (totalEDays != 0) {
  a = nepali_years_and_days_in_months[i][j];
  totalNDays++;
  day++;
  if (totalNDays > a) {
  m++;
  totalNDays = 1;
  j++;
  }
  if (day > 7)
  day = 1;
  if (m > 12) {
  y++;
  m = 1;
  }
  if (j > 12) {
  j = 1;
  i++;
  }
  totalEDays--;
  }

  String barsa = localizeNumber(y.toString());
  String mahina = localizeNumber(zeroPad(m, 2));
  String totaldays = localizeNumber(zeroPad(totalNDays, 2)) ;

 return ("$barsa-$mahina-$totaldays");


  }








}
