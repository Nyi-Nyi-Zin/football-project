package logger

import (
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var log *zap.SugaredLogger

// Init initializes the Zap logger
func Init(env string) {
	var cfg zap.Config

	if env == "production" {
		cfg = zap.NewProductionConfig()
		cfg.EncoderConfig.TimeKey = "timestamp"
		cfg.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	} else {
		cfg = zap.NewDevelopmentConfig()
		cfg.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	}

	logger, err := cfg.Build(zap.AddCallerSkip(1))
	if err != nil {
		panic("logger.Init: failed to initialize logger: " + err.Error())
	}

	log = logger.Sugar()
}

// Info logs an info message
func Info(msg string, keysAndValues ...interface{}) {
	log.Infow(msg, keysAndValues...)
}

// Error logs an error message
func Error(msg string, keysAndValues ...interface{}) {
	log.Errorw(msg, keysAndValues...)
}

// Warn logs a warning message
func Warn(msg string, keysAndValues ...interface{}) {
	log.Warnw(msg, keysAndValues...)
}

// Debug logs a debug message
func Debug(msg string, keysAndValues ...interface{}) {
	log.Debugw(msg, keysAndValues...)
}

// Fatal logs a fatal message and exits
func Fatal(msg string, keysAndValues ...interface{}) {
	log.Fatalw(msg, keysAndValues...)
}

// Sync flushes any buffered log entries
func Sync() {
	if log != nil {
		_ = log.Sync()
	}
}
