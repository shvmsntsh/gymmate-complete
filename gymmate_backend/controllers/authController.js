// DEPRECATED: Do not use this controller. Use userController.js for all login logic.
module.exports = {
  login: (req, res) => {
    res.status(500).json({ message: 'authController.js is deprecated. Use userController.js for login.' });
  }
}; 