const editorconfigDefaults = {
  endOfLine: 'lf',
  useTabs: false,
  tabWidth: 2,
  printWidth: 80,
} // Do not edit

const config = {
  ...editorconfigDefaults,
  semi: false,
  singleQuote: true,
  quoteProps: 'consistent',
  overrides: [
    {
      files: ['*.md'],
      options: {
        tabWidth: 4,
      },
    },
    {
      files: ['*.html', '*.xml'],
      options: {},
    },
  ],
}

export default config
