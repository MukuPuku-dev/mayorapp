import 'package:test/test.dart';
import 'package:mayorapp/DateConvert.dart'; // Adjust this import path if your DateConverter.dart is located elsewhere relative to the lib folder.

void main() {
  group('DateConverter.convertEnglishDateToNepali', () {
    test('should convert 2023-10-26 (AD) to २०८०-०७-०९ (BS) correctly', () {
      expect(DateConverter.convertEnglishDateToNepali(2023, 10, 26), equals('२०८०-०७-०९'));
    });

    test('should convert 1944-01-01 (AD) to २०००-०९-१७ (BS) - (Reference Start Date)', () {
      // This test case is based on the common reference point for AD to BS conversion.
      // The internal logic of the converter uses 2000/9/17 as its base.
      // If the function is designed to convert 1944/1/1 AD exactly to 2000/09/17 BS, this test is valid.
      // The current output of the function for 1944/1/1 might be "२०००-०९-१८" if it's 1-indexed for the day internally after conversion.
      // Let's assume the provided data array implies 2000/9/17 is the start.
      // The code has `defNdd = 17 - 1;` which means it starts counting from `defNdd` for the total days.
      // For 1944/1/1, totalEDays is 1. The loop runs once. totalNDays becomes defNdd + 1 = 17. So it should be 17.
      expect(DateConverter.convertEnglishDateToNepali(1944, 1, 1), equals('२०००-०९-१७'));
    });

    test('should convert 2000-02-29 (AD Leap Day) correctly', () {
      // Example: February 29, 2000 (Leap Year)
      // This date needs to be manually calculated or verified with a reliable converter.
      // For this example, let's assume a placeholder. Replace with actual expected BS date.
      // According to online converters, 2000-02-29 AD is 2056-11-17 BS.
      expect(DateConverter.convertEnglishDateToNepali(2000, 2, 29), equals('२०५६-११-१७'));
    });
    
    test('should convert 2024-03-10 (AD) to २०८०-११-२७ (BS) correctly', () {
        // Verified with online converter for a recent date
        expect(DateConverter.convertEnglishDateToNepali(2024, 3, 10), equals('२०८०-११-२७'));
    });

    test('should handle a date at the beginning of a Nepali month correctly', () {
        // Example: 2023-04-14 AD is 2080-01-01 BS (Baisakh 1st, Nepali New Year)
        expect(DateConverter.convertEnglishDateToNepali(2023, 4, 14), equals('२०८०-०१-०१'));
    });

    test('should handle a date at the end of a Nepali month correctly', () {
        // Example: 2023-05-14 AD is 2080-01-31 BS (Baisakh 31st)
        expect(DateConverter.convertEnglishDateToNepali(2023, 5, 14), equals('२०८०-०१-३१'));
    });

     test('should return "Invalid date !" for dates outside the supported range (before 1944 AD)', () {
      expect(DateConverter.convertEnglishDateToNepali(1943, 12, 31), equals('Invalid date !'));
    });

    test('should return "Invalid date !" for dates outside the supported range (after 2033 AD)', () {
      // The current nepali_years_and_days_in_months goes up to 2090 BS, which is around 2033/2034 AD.
      // The check in the code is `year > 2033`. So 2034 should be invalid.
      expect(DateConverter.convertEnglishDateToNepali(2034, 1, 1), equals('Invalid date !'));
    });

  });

  group('DateConverter.getNepaliDayOfWeekInString', () {
    test('should convert English day names to Nepali correctly', () {
      expect(DateConverter.getNepaliDayOfWeekInString("Sunday"), equals('आइतबार'));
      expect(DateConverter.getNepaliDayOfWeekInString("Monday"), equals('सोमबार'));
      expect(DateConverter.getNepaliDayOfWeekInString("Tuesday"), equals('मंगलबार'));
      expect(DateConverter.getNepaliDayOfWeekInString("Wednesday"), equals('बुधबार'));
      expect(DateConverter.getNepaliDayOfWeekInString("Thursday"), equals('बिहिबार'));
      expect(DateConverter.getNepaliDayOfWeekInString("Friday"), equals('शुक्रबार'));
      expect(DateConverter.getNepaliDayOfWeekInString("Saturday"), equals('शनिबार'));
    });

    test('should return "Error Day" for invalid English day name', () {
      expect(DateConverter.getNepaliDayOfWeekInString("InvalidDay"), equals('Error Day'));
    });
  });
}
