/** Annotation helpers — reporter reads type=testmo for the Pass list. */
export function testmoCase(module: string, caseTitle: string) {
  return [
    { type: 'module' as const, description: module },
    { type: 'testmo' as const, description: caseTitle },
  ];
}
