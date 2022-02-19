module.exports = {
  apps : [{
    name: "Fauxton",
    script: "./node_modules/fauxton/bin/fauxton",
    args: "-p 8001"
  }, {
    name: "TurnKey Linux CP",
    script: "./tklweb-cp.js"
  }],

  deploy : {
  }
};
