/// Provides utility methods for date conversions, primarily between English (AD) and Nepali (BS) dates.
class DateConverter {
  /// Data for Nepali years and the number of days in each month for that year.
  /// Each inner list represents a Nepali year:
  /// - The first element is the Nepali year (e.g., 2000).
  /// - The subsequent 12 elements are the number of days in each month of that year,
  ///   starting from Baisakh (month 1) to Chaitra (month 12).
  /// This data is crucial for the AD to BS conversion logic.
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
    [2039, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
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

  /// Converts an English (Gregorian) day of the week string to its Nepali equivalent.
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
        return "Error Day"; // Should not happen with valid English day names
    }
  }

  /// Converts a given English date (year [yy], month [mm], day [dd]) to its corresponding
  /// Nepali date (Bikram Sambat).
  ///
  /// The conversion algorithm is based on a reference English date (1944/1/1 AD) and its
  /// corresponding Nepali date (2000/9/17 BS). It calculates the total number of days
  /// passed since the English reference date and then iterates through the Nepali calendar
  /// data ([nepali_years_and_days_in_months]) to find the equivalent Nepali date.
  ///
  /// Returns the Nepali date as a string in "YYYY-MM-DD" format, with numbers localized to Nepali script.
  /// Returns "Invalid date !" if the input English date is outside the supported range (1944 AD to 2033 AD).
  static String convertEnglishDateToNepali(int yy, int mm, int dd) {
    // Helper function (unused locally, consider removing or making private if not used elsewhere)
    bool isSameDay(DateTime d1, DateTime d2) {
      if (d1 is DateTime && d2 is DateTime) {
        return (d1.year == d2.year) &&
            (d1.month == d2.month) &&
            (d1.day == d2.day);
      } else {
        return false;
      }
    }

    /// Determines if a given [year] is a leap year in the Gregorian calendar.
    bool isLeapYear(int year) {
      if (year % 100 == 0) {
        return (year % 400 == 0);
      } else {
        return (year % 4 == 0);
      }
    }

    // Helper function (unused locally, consider removing or making private if not used elsewhere)
    String getNepaliMonthInString(int month) {
      String nepaliMonth = "";
      switch (month) {
        case 1:
          nepaliMonth = "बैशाख";
          break;
        // ... (cases for other months)
        default:
          nepaliMonth = "";
      }
      return nepaliMonth;
    }

    // Helper function (unused locally, consider removing or making private if not used elsewhere)
    String getEnglishMonth(int month) {
      String englishMonth = "";
      switch (month) {
        case 1:
          englishMonth = "Baisakh";
          break;
        // ... (cases for other months)
        default:
          englishMonth = "";
      }
      return englishMonth;
    }

    // Helper function (unused locally, consider removing or making private if not used elsewhere)
    String getEnglishDayOfWeekInString(int day) {
      switch (day) {
        case 1:
          return "Sunday";
        // ... (cases for other days)
        default:
          return "";
      }
    }

    /// Prepends a '0' to a number if it's less than 10, for two-digit formatting.
    String zeroPad(int num, int places) {
      return num.toString().padLeft(places, '0');
    }

    /// Checks if the provided English date is within the algorithm's supported range.
    bool checkIfDateIsInRange(int year, int month, int day) {
      if (year < 1944 || year > 2033) {
        return false;
      }
      if (month < 1 || month > 12) {
        return false;
      }
      return !(day < 1 || day > 31); // Basic day check, month-specific day limits handled by day calculation
    }

    // Helper function (unused locally, consider removing or making private if not used elsewhere)
    String addZero(int i) {
      if (i < 10) {
        return "0$i";
      }
      return i.toString();
    }

    /// Checks if a given string [n] can be parsed as a number.
    bool isNumeric(n) {
      return n != null && double.tryParse(n.toString()) != null;
    }

    /// Converts an English digit string to its Nepali numeral equivalent.
    String englishToNepaliNumber(String number) { // Parameter changed to String for direct use with string characters
      switch (number) {
        case "0": return "०";
        case "1": return "१";
        case "2": return "२";
        case "3": return "३";
        case "4": return "४";
        case "5": return "५";
        case "6": return "६";
        case "7": return "७";
        case "8": return "८";
        case "9": return "९";
        default: return number; // Return original if not a single digit string
      }
    }

    /// Converts all numeric characters in a string [temp] to Nepali numerals.
    String localizeNumber(String temp) {
      String result = "";
      for (int i = 0; i < temp.length; i++) {
        if (isNumeric(temp[i])) {
          result += englishToNepaliNumber(temp[i]);
        } else {
          result += temp[i];
        }
      }
      return result;
    }

    // Validate input English date range
    if (!checkIfDateIsInRange(yy, mm, dd)) {
      return "Invalid date !";
    }

    // Gregorian month days (non-leap and leap year)
    List<int> monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    List<int> leapYearMonthDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    // Reference English date: 1944 January 1 AD
    int refEnglishYear = 1944;
    // Corresponding Nepali date: 2000 Poush 17 BS (adjusting day for 0-based calculation later)
    int refNepaliYear = 2000;
    int refNepaliMonth = 9; // Poush
    int refNepaliDay = 17 - 1; // Day is 0-indexed in calculation loop initially

    int totalEnglishDays = 0;

    // Calculate total days from reference English year up to (but not including) the input English year
    for (int i = 0; i < (yy - refEnglishYear); i++) {
      if (isLeapYear(refEnglishYear + i)) {
        for (int j = 0; j < 12; j++) {
          totalEnglishDays += leapYearMonthDays[j];
        }
      } else {
        for (int j = 0; j < 12; j++) {
          totalEnglishDays += monthDays[j];
        }
      }
    }

    // Add days for months passed in the input English year
    for (int i = 0; i < (mm - 1); i++) {
      if (isLeapYear(yy)) {
        totalEnglishDays += leapYearMonthDays[i];
      } else {
        totalEnglishDays += monthDays[i];
      }
    }

    // Add days of the input English month
    totalEnglishDays += dd;

    int currentNepaliDay = refNepaliDay;
    int currentNepaliMonth = refNepaliMonth;
    int currentNepaliYear = refNepaliYear;
    int nepaliYearDataIndex = 0; // Index for nepali_years_and_days_in_months

    // Iterate, subtracting days from totalEnglishDays and adding to Nepali date
    while (totalEnglishDays != 0) {
      // Find the correct year's data in nepali_years_and_days_in_months
      while(nepali_years_and_days_in_months[nepaliYearDataIndex][0] != currentNepaliYear && nepaliYearDataIndex < nepali_years_and_days_in_months.length -1) {
        nepaliYearDataIndex++;
      }
      
      int daysInCurrentNepaliMonth = nepali_years_and_days_in_months[nepaliYearDataIndex][currentNepaliMonth];
      
      currentNepaliDay++;
      if (currentNepaliDay > daysInCurrentNepaliMonth) {
        currentNepaliMonth++;
        currentNepaliDay = 1;
        if (currentNepaliMonth > 12) {
          currentNepaliYear++;
          currentNepaliMonth = 1;
          // Update nepaliYearDataIndex if year changes, though the while loop above should handle it.
          // This ensures if we cross into a new year not immediately following the current one in the list,
          // we re-search for the correct year's data.
          nepaliYearDataIndex = 0; 
        }
      }
      totalEnglishDays--;
    }

    String barsa = localizeNumber(currentNepaliYear.toString());
    String mahina = localizeNumber(zeroPad(currentNepaliMonth, 2));
    String gate = localizeNumber(zeroPad(currentNepaliDay, 2));

    return ("$barsa-$mahina-$gate");
  }
}
