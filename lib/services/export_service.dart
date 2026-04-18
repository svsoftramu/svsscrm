import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/status_helpers.dart';

class ExportService {
  static final ExportService instance = ExportService._();
  ExportService._();

  Future<File> generateInvoicePdf(Map<String, dynamic> invoice) async {
    final pdf = pw.Document();
    final number = invoice['number'] ?? invoice['invoice_number'] ?? '#${invoice['id'] ?? ''}';
    final clientName = invoice['client_name'] ?? invoice['company'] ?? invoice['customer_name'] ?? '';
    final total = invoice['total'] ?? invoice['amount'] ?? '0';
    final date = invoice['date'] ?? invoice['datecreated'] ?? '';
    final dueDate = invoice['duedate'] ?? invoice['due_date'] ?? '';
    final status = invoice['status']?.toString() ?? '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SV Soft Solutions', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(number.toString(), style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.blue800, thickness: 2),
            pw.SizedBox(height: 20),
            _pdfRow('Bill To:', clientName.toString()),
            _pdfRow('Date:', date.toString()),
            if (dueDate.toString().isNotEmpty) _pdfRow('Due Date:', dueDate.toString()),
            _pdfRow('Status:', _invoiceStatusLabel(status)),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            // Items if available
            if (invoice['items'] is List) ...[
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellPadding: const pw.EdgeInsets.all(8),
                headers: ['Item', 'Qty', 'Rate', 'Amount'],
                data: (invoice['items'] as List).map((item) => [
                  item['description'] ?? item['name'] ?? '',
                  item['qty']?.toString() ?? '1',
                  item['rate']?.toString() ?? '0',
                  item['amount']?.toString() ?? '0',
                ]).toList(),
              ),
              pw.SizedBox(height: 20),
            ],
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text('Total: Rs. $total', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              ),
            ),
          ],
        ),
      ),
    );

    return _savePdf(pdf, 'invoice_$number');
  }

  Future<File> generateEstimatePdf(Map<String, dynamic> estimate) async {
    final pdf = pw.Document();
    final number = estimate['number'] ?? estimate['estimate_number'] ?? '#${estimate['id'] ?? ''}';
    final clientName = estimate['client_name'] ?? estimate['company'] ?? estimate['customer_name'] ?? '';
    final total = estimate['total'] ?? estimate['amount'] ?? '0';
    final date = estimate['date'] ?? estimate['datecreated'] ?? '';
    final expiryDate = estimate['expirydate'] ?? estimate['expiry_date'] ?? '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SV Soft Solutions', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('ESTIMATE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(number.toString(), style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.blue800, thickness: 2),
            pw.SizedBox(height: 20),
            _pdfRow('Client:', clientName.toString()),
            _pdfRow('Date:', date.toString()),
            if (expiryDate.toString().isNotEmpty) _pdfRow('Valid Until:', expiryDate.toString()),
            pw.SizedBox(height: 30),
            if (estimate['items'] is List) ...[
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellPadding: const pw.EdgeInsets.all(8),
                headers: ['Item', 'Qty', 'Rate', 'Amount'],
                data: (estimate['items'] as List).map((item) => [
                  item['description'] ?? item['name'] ?? '',
                  item['qty']?.toString() ?? '1',
                  item['rate']?.toString() ?? '0',
                  item['amount']?.toString() ?? '0',
                ]).toList(),
              ),
              pw.SizedBox(height: 20),
            ],
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text('Total: Rs. $total', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              ),
            ),
          ],
        ),
      ),
    );

    return _savePdf(pdf, 'estimate_$number');
  }

  Future<File> generateReportPdf(String title, List<Map<String, dynamic>> data, List<String> columns) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: title, textStyle: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Generated on: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(color: PdfColors.grey600)),
          pw.SizedBox(height: 20),
          if (data.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellPadding: const pw.EdgeInsets.all(6),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: columns,
              data: data.map((row) => columns.map((col) => (row[col] ?? '').toString()).toList()).toList(),
            )
          else
            pw.Text('No data available', style: const pw.TextStyle(color: PdfColors.grey)),
        ],
      ),
    );

    return _savePdf(pdf, 'report_${title.replaceAll(' ', '_').toLowerCase()}');
  }

  Future<File> exportToCsv(String filename, List<Map<String, dynamic>> data, List<String> columns) async {
    final rows = <List<dynamic>>[columns];
    for (final row in data) {
      rows.add(columns.map((col) => (row[col] ?? '').toString()).toList());
    }
    final csvStr = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.csv');
    await file.writeAsString(csvStr);
    return file;
  }

  Future<void> shareFile(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }

  Future<File> _savePdf(pw.Document pdf, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  String _invoiceStatusLabel(String status) => invoiceStatusLabel(status);
}
