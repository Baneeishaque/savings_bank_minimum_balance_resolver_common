import 'dart:collection';
import 'dart:io';

import 'package:grizzly_io/io_loader.dart';
import 'package:savings_bank_minimum_balance_resolver_common/daily_balance.dart';
import 'package:savings_bank_minimum_balance_resolver_common/date_formats.dart';
import 'package:savings_bank_minimum_balance_resolver_common/transaction.dart';

import 'input_utils.dart';

double _getCurrentAverageDailyBalance(
    double sumOfDailyBalances, int numberOfDays) {
  return sumOfDailyBalances / numberOfDays;
}

Future<List<DailyBalance>> _readDailyBalancesFromCsv(String csvPath) async {
  List<DailyBalance> dailyBalances = List.empty(growable: true);
  for (List<String> row in (await readCsv(csvPath))) {
    dailyBalances.add(DailyBalance(
        date: normalDateFormat.parseStrict(row[0]),
        balance: double.parse(row[1])));
  }
  return dailyBalances;
}

double _getCurrentAverageDailyBalanceFromDailyBalanceList(
    List<DailyBalance> dailyBalances) {
  double sumOfDailyBalances = 0;
  for (DailyBalance dailyBalance in dailyBalances) {
    sumOfDailyBalances += dailyBalance.balance;
  }
  return _getCurrentAverageDailyBalance(
      sumOfDailyBalances, dailyBalances.length);
}

Future<double> _getCurrentAverageDailyBalanceFromCsv(String csvPath) async {
  return _getCurrentAverageDailyBalanceFromDailyBalanceList(
      await _readDailyBalancesFromCsv(csvPath));
}

Future<List<Transaction>> _readTransactionsFromCsv(String csvPath) async {
  List<Transaction> transactions = List.empty(growable: true);
  for (List<String> row in (await readCsv(csvPath))) {
    transactions.add(Transaction(
        date: normalDateFormat.parseStrict(row[0]),
        amount: double.parse(row[1])));
  }
  return transactions;
}

Future<Map<DateTime, double>> _calculateDailyBalancesFromTransactionsCsvCommon(
    DateTime upToDate,
    double lastBalance,
    DateTime fromDate,
    Map<DateTime, double> transactionSums) async {
  return _fillMissingDailyBalances(_fillDailyBalancesFromDate(
      fromDate,
      _fillDailyBalancesUpToAvailableDate(
          upToDate, transactionSums, lastBalance)));
}

Future<Map<DateTime, double>> _calculateDailyBalancesFromTransactionsCsvCli(
    Map<DateTime, double> transactionSums) async {
  DateTime upToDate = _getUpToDateCli(transactionSums.keys.first);
  double lastBalance =
      getValidDoubleCli('Enter the last balance on $upToDate : ');
  return _calculateDailyBalancesFromTransactionsCsvCommon(upToDate, lastBalance,
      _getFromDateCli(transactionSums.keys.last), transactionSums);
}

SplayTreeMap<DateTime, double> _fillMissingDailyBalances(
    SplayTreeMap<DateTime, double> dailyBalances) {
  DateTime lowerDate = dailyBalances.keys.first;
  double dayBalance = 0;
  while (lowerDate != dailyBalances.keys.last) {
    if (dailyBalances.containsKey(lowerDate)) {
      dayBalance = dailyBalances[lowerDate]!;
    } else {
      dailyBalances[lowerDate] = dayBalance;
    }
    lowerDate = lowerDate.add(Duration(days: 1));
  }
  return dailyBalances;
}

SplayTreeMap<DateTime, double> _fillDailyBalancesFromDate(
    DateTime? secondFromDate, SplayTreeMap<DateTime, double> dailyBalances) {
  if (secondFromDate != null) {
    DateTime fromDate = dailyBalances.keys.first;
    double lowerBalance = dailyBalances.values.first;
    while (fromDate != secondFromDate) {
      fromDate = fromDate.subtract(Duration(days: 1));
      dailyBalances[fromDate] = lowerBalance;
    }
  }
  return dailyBalances;
}

DateTime _getFromDateCli(DateTime fromDate) {
  print('Calculate Daily Balance from $fromDate (Y/N - Just Enter for Yes) : ');
  String? fromDateInput = stdin.readLineSync();
  if (fromDateInput != "") {
    fromDate = getValidNormalLowerDateCli(fromDate);
  }
  return fromDate;
}

SplayTreeMap<DateTime, double> _fillDailyBalancesUpToAvailableDate(
    DateTime upToDate,
    Map<DateTime, double> transactionSums,
    double lastBalance) {
  SplayTreeMap<DateTime, double> dailyBalances =
      SplayTreeMap((k1, k2) => k1.compareTo(k2));
  while (upToDate != transactionSums.keys.first) {
    dailyBalances[upToDate] = lastBalance;
    upToDate = upToDate.subtract(Duration(days: 1));
  }
  transactionSums.forEach((key, value) {
    dailyBalances[key] = lastBalance;
    lastBalance += value;
  });
  return dailyBalances;
}

DateTime _getUpToDateCli(DateTime upToDate) {
  print(
      'Calculate Daily Balance up-to $upToDate (Y/N - Just Enter for Yes) : ');
  String? upToDateInput = stdin.readLineSync();
  if (upToDateInput != "") {
    upToDate = getValidNormalGreaterDateCli(upToDate);
  }
  return upToDate;
}

Future<Map<DateTime, double>> _prepareTransactionSums(String csvPath) async {
  List<Transaction> transactions = await _readTransactionsFromCsv(csvPath);
  Map<DateTime, double> transactionSums = {};
  DateTime? currentDateOfTransaction;
  double currentDayTransactionBalance = 0;
  for (Transaction transaction in transactions) {
    currentDateOfTransaction ??= transaction.date;
    if (transaction == transactions.last) {
      transactionSums[currentDateOfTransaction] =
          currentDayTransactionBalance + transaction.amount;
      break;
    } else if (currentDateOfTransaction.compareTo(transaction.date) != 0) {
      transactionSums[currentDateOfTransaction] = currentDayTransactionBalance;
      currentDateOfTransaction = transaction.date;
      currentDayTransactionBalance = 0;
    }
    currentDayTransactionBalance += transaction.amount;
  }
  return transactionSums;
}

double _getCurrentAverageDailyBalanceFromDailyBalanceMap(
    Map<DateTime, double> dailyBalances) {
  double sumOfDailyBalances = 0;
  dailyBalances.forEach((key, value) {
    sumOfDailyBalances += value;
  });
  return _getCurrentAverageDailyBalance(
      sumOfDailyBalances, dailyBalances.length);
}

Future<double> getCurrentAverageDailyBalanceFromTransactionsCsvCli(
    String csvPath) async {
  return _getCurrentAverageDailyBalanceFromDailyBalanceMap(
      await _calculateDailyBalancesFromTransactionsCsvCli(
          await _prepareTransactionSums(csvPath)));
}
