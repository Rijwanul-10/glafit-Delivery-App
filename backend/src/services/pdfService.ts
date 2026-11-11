import PDFDocument from 'pdfkit';

export async function generateReceiptPdf(params: {
  title: string;
  subtitle: string;
  referenceCode: string;
  lines: Array<{ label: string; value: string }>;
  totalLabel: string;
  totalValue: string;
}): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A5', margin: 36 });
    const chunks: Buffer[] = [];
    doc.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc.rect(0, 0, doc.page.width, 72).fill('#092113');
    doc.fillColor('#FFFFFF').fontSize(18).text('2Bee', 36, 20);
    doc.fontSize(10).fillColor('#8CF07C').text(params.subtitle, 36, 44);

    doc.moveDown(2);
    doc.fillColor('#101C0C').fontSize(14).text(params.title, 36, 90);
    doc.fontSize(10).fillColor('#545C70').text(`Reference: ${params.referenceCode}`);
    doc.text(`Generated: ${new Date().toISOString()}`);

    doc.moveDown(1);
    doc.moveTo(36, doc.y).lineTo(doc.page.width - 36, doc.y).strokeColor('#D0ECDC').stroke();
    doc.moveDown(0.8);

    for (const line of params.lines) {
      const y = doc.y;
      doc.fillColor('#545C70').fontSize(10).text(line.label, 36, y, { width: 180 });
      doc.fillColor('#101C0C').fontSize(10).text(line.value, 220, y, { width: doc.page.width - 256, align: 'right' });
      doc.moveDown(0.5);
    }

    doc.moveDown(0.5);
    doc.moveTo(36, doc.y).lineTo(doc.page.width - 36, doc.y).strokeColor('#006C04').stroke();
    doc.moveDown(0.8);
    const ty = doc.y;
    doc.fillColor('#006C04').fontSize(12).text(params.totalLabel, 36, ty);
    doc.fontSize(12).text(params.totalValue, 220, ty, { width: doc.page.width - 256, align: 'right' });

    doc.end();
  });
}

