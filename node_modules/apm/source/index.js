function Module (options) {
	this.options = options;
	this.accuracy = options.accuracy || 1;
	this.timeSpan = options.timeSpan || 60;
	if (this.accuracy > this.timeSpan) {
		throw new Error('invalid arguments');
	}
	this.data = [];
	for (var i = 0; i < this.timeSpan; i += this.accuracy) {
		this.data[i] = {
			lastUpdate: 0,
			amount: 0
		};
	}
}

Module.prototype.action = function (id, amount) {
	if (!amount) {
		amount = 1;
	}
	var index = Math.floor(
		(
			Date.now() % (
				this.timeSpan * 1000
			)
		) / (
			this.accuracy * 1000
		)
	);
	if (this.data[index].lastUpdate - Date.now() > (this.timeSpan * 1000)) {
		this.data[index].amount = 0;
	}
	this.data[index].lastUpdate = Date.now();
	this.data[index].amount += amount;
};

Module.prototype.get = function () {
	var result = 0;
	this.data.forEach(function (e) {
		if (e.lastUpdate - Date.now() > (this.timeSpan * 1000)) {
			result += e.amount;
		}
	});
	return result;
};

module.exports = Module;
