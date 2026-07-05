const editorconfigOverrides = {
  endOfLine: 'lf',
  useTabs: false,
  tabWidth: 2,
  printWidth: 80,
}

const config = {
  ...editorconfigOverrides,
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
