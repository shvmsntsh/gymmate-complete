const { app, connectToMongo } = require('../app');

module.exports = async (req, res) => {
  await connectToMongo();
  return app(req, res);
};
