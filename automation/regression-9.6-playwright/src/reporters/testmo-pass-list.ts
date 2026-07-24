import type {
  FullConfig,
  FullResult,
  Reporter,
  TestCase,
  TestResult,
} from '@playwright/test/reporter';

type Row = {
  module: string;
  caseTitle: string;
  status: 'passed' | 'failed' | 'skipped' | 'timedOut' | 'interrupted';
};

/**
 * After a run, prints which Testmo cases to mark Pass (from annotation type=testmo).
 * Wired for `npm run test:smoke`.
 */
class TestmoPassListReporter implements Reporter {
  private rows: Row[] = [];

  onTestEnd(test: TestCase, result: TestResult): void {
    const testmo = test.annotations.filter((a) => a.type === 'testmo');
    if (testmo.length === 0) return;

    const moduleAnn = test.annotations.find((a) => a.type === 'module');
    const module = moduleAnn?.description ?? guessModule(test);

    for (const ann of testmo) {
      if (!ann.description) continue;
      this.rows.push({
        module,
        caseTitle: ann.description,
        status: result.status,
      });
    }
  }

  onEnd(result: FullResult): void {
    if (this.rows.length === 0) return;

    const passed = this.rows.filter((r) => r.status === 'passed');
    const failed = this.rows.filter((r) => r.status === 'failed' || r.status === 'timedOut');
    const skipped = this.rows.filter((r) => r.status === 'skipped');

    const line = '═'.repeat(72);
    console.log(`\n${line}`);
    console.log('TESTMO — mark from this run');
    console.log(line);

    if (passed.length) {
      console.log('\nMark as PASS:\n');
      printGrouped(passed);
    } else {
      console.log('\nNo cases to mark PASS (none passed with testmo annotations).');
    }

    if (failed.length) {
      console.log('\nDo NOT mark PASS (failed):\n');
      printGrouped(failed);
    }

    if (skipped.length) {
      console.log('\nSkipped (leave as-is / not this smoke):\n');
      printGrouped(skipped);
    }

    console.log(`\nRun status: ${result.status}`);
    console.log(`${line}\n`);
  }

  // unused hooks — satisfy interface
  onBegin(_config: FullConfig): void {}
}

function guessModule(test: TestCase): string {
  const file = test.location.file;
  if (file.includes('/cnp/')) return 'CNP';
  if (file.includes('/tokenvault/')) return 'TokenVault';
  if (file.includes('/pay-2603/')) return 'PAY-2603';
  if (file.includes('/treasury/')) return 'Treasury';
  if (file.includes('/wallet/')) return 'Wallet';
  if (file.includes('/provisioning/')) return 'Wellfit Provisioning';
  return 'Regression';
}

function printGrouped(rows: Row[]): void {
  const byModule = new Map<string, string[]>();
  for (const r of rows) {
    const list = byModule.get(r.module) ?? [];
    if (!list.includes(r.caseTitle)) list.push(r.caseTitle);
    byModule.set(r.module, list);
  }
  for (const [mod, titles] of byModule) {
    console.log(`  [${mod}]`);
    for (const t of titles) {
      console.log(`    • ${t}`);
    }
    console.log('');
  }
}

export default TestmoPassListReporter;
