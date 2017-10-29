<?php
/**
 * Created by PhpStorm.
 * User: sx
 * Date: 2017/10/29
 * Time: 10:36
 */

namespace Zsxsoft\AppValidator\Tasks;

use Zsxsoft\AppValidator\Helpers\Logger;

class GlobalVariables
{

    private $store = [];

    /**
     * Load globals and save them to the store
     * @param string $class
     * @param callable $callback
     */
    public function loadGlobals($class, callable $callback)
    {
        $this->store[$class] = [
            "callback" => $callback,
            "data" => $callback(),
        ];
    }

    /**
     * Compare new data and original data
     * @param string $class
     * @return array diff
     */
    public function diffGlobals($class)
    {
        return array_diff($this->store[$class]['callback'](), $this->store[$class]['data']);
    }

    /**
     * Check the name of functions
     * @param array $diff
     */
    public function checkFunctions($diff)
    {
        global $app;
        Logger::info('Testing functions');
        $regex = str_replace("!!", $app->id, "/^(activeplugin_|installplugin_|uninstallplugin_)!!$|^!!_|^!!$|_!!$/si");
        //var_dump($diff);exit;
        foreach ($diff as $index => $name) {
            if (preg_match($regex, $name)) {
                Logger::info('Tested function: ' . $name);
            } else {
                Logger::error('Sub-standard function: ' . $name, false);
                if ($ret = Utils::getFunctionDescription($name)) {
                    Logger::error("In " . $ret->getFileName(), false);
                    Logger::error("Line " . ($ret->getStartLine() - 1) . " To " . ($ret->getEndLine() - 1), false);
                }
                Logger::error("Exited");
            }
        }
    }

    /**
     * Check global variables / constants / class
     * @param string $class
     * @param array $diff
     * @return bool
     */
    public function checkOthers($class, $diff)
    {
        global $app;
        Logger::info('Testing ' . $class);
        $regex = str_replace("!!", $app->id, "/^!!_?/si");
        foreach ($diff as $index => $name) {
            if (preg_match($regex, $name)) {
                Logger::info('Tested ' . $class . ': ' . $name);
            } else {
                Logger::error('Sub-standard ' . $class . ': ' . $name);
            }
        }

        return true;
    }

    /**
     * Call check functions
     * @param string $class
     * @return bool
     */
    public function checkDiff($class)
    {
        $diff = $this->diffGlobals($class);
        $function = 'Check' . ucfirst($class);
        if (method_exists(__CLASS__, $function)) {
            return call_user_func(array(__CLASS__, $function), $diff);
        }

        return $this->checkOthers($class, $diff);
    }

    /**
     * Runner
     */
    public function run()
    {
        global $zbp;
        global $app;

        Logger::info('Scanning functions and global variables');
        $this->loadGlobals('variables', function () {
            return array_keys($GLOBALS);
        });
        $this->loadGlobals('functions', function () {
            return get_defined_functions()['user'];
        });
        $this->loadGlobals('constants', function () {
            return array_keys(get_defined_constants());
        });
        $this->loadGlobals('classes__', function () {
            return get_declared_classes();
        });
        $filename = $zbp->path . '/zb_users/' . $app->type . '/' . $app->id . '/include.php';

        $includeFlag = Utils::includeFile($filename);
        if ($includeFlag === true) {
            if (!is_readable($filename)) {
                Logger::info('No include file.');
            } else {
                Log::warning('You\'d better disable this app before check.');
            }
            return;
        }

        $this->checkDiff('variables');
        $this->checkDiff('functions');
        $this->checkDiff('constants');
        $this->checkDiff('classes__');
    }
}
