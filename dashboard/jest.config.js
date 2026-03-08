module.exports = {
    testEnvironment: "jest-environment-jsdom",
    transform: {
        "^.+\\.(js|jsx|mjs)$": "babel-jest",
    },
    moduleNameMapper: {
        "\\.(css|less|scss|sass)$": "identity-obj-proxy",
    },
    setupFilesAfterEnv: ["<rootDir>/jest.setup.js"],
};
